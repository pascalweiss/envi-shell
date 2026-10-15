// The daemon: starts Vivaldi on the CDP pipe, which only it holds, and serves the whitelist in
// ops.mjs on the unix socket.

import {spawn} from 'node:child_process';
import net from 'node:net';
import fs from 'node:fs';
import {PROFILE, STATE, SOCK, BROWSER, OPEN_OPS, LEASE_MS, UserError, checkSocketPath, checkAuthSetup, log, request} from './common.mjs';
import {connect} from './browser.mjs';
import {pageAccess} from './pages.mjs';
import {createLock} from './lock.mjs';
import {createOps} from './ops.mjs';

export async function daemon() {
  checkSocketPath();
  fs.mkdirSync(STATE, {recursive: true, mode: 0o700});
  fs.chmodSync(STATE, 0o700);
  checkAuthSetup();
  if (await request({op: 'ping'}).then(() => true, () => false)) throw new UserError('daemon is already running');
  fs.rmSync(SOCK, {force: true});

  const proc = spawn(BROWSER, ['--remote-debugging-pipe', `--user-data-dir=${PROFILE}`, '--no-first-run'],
    {stdio: ['ignore', 'ignore', 'ignore', 'pipe', 'pipe']});
  const [toB, fromB] = [proc.stdio[3], proc.stdio[4]];
  toB.on('error', () => {});
  log(`started Vivaldi pid ${proc.pid} on profile ${PROFILE}`);

  const browser = connect(toB, fromB);
  const lock = createLock();
  const OPS = createOps({browser, pages: pageAccess(browser), lock});

  // Requests run one at a time: two interleaved tab moves would confuse the UI.
  let queue = Promise.resolve();
  const server = net.createServer(conn => {
    let data = '';
    conn.on('error', () => {});
    conn.on('data', d => {
      data += d;
      if (!data.includes('\n')) return;
      const line = data.slice(0, data.indexOf('\n')); data = '';
      let req;
      try { req = JSON.parse(line); } catch { req = {}; }
      const run = async () => {
        let reply;
        try {
          if (!Object.hasOwn(OPS, req.op)) throw new UserError(`unknown operation "${req.op}"`);
          if (!OPEN_OPS.has(req.op) && lock.isLocked()) {
            throw new UserError(`locked: ask the user to run \`vivctl unlock\` (Touch ID), access then lasts ${LEASE_MS / 60000} minutes`);
          }
          reply = {ok: true, result: await OPS[req.op](req)};
        } catch (e) {
          reply = {ok: false, error: e.message, user: e instanceof UserError};
        }
        conn.end(JSON.stringify(reply) + '\n');
      };
      // ping, unlock and lock must not wait behind a tab operation (or a Touch ID sheet).
      if (OPEN_OPS.has(req.op)) run(); else queue = queue.then(run);
    });
  });
  server.listen(SOCK, () => { fs.chmodSync(SOCK, 0o600); log('listening'); });

  const stop = () => proc.kill('SIGTERM');
  process.on('SIGTERM', stop); process.on('SIGINT', stop);
  proc.on('exit', (code, sig) => {
    log(`Vivaldi exited (code ${code}, signal ${sig})`);
    // A second launch on a profile that is already open hands over to the running
    // instance and exits at once, which leaves this daemon without a pipe.
    if (Date.now() - startedAt < 10000) log('Vivaldi exited right after the start: is it already running on this profile without the pipe?');
    server.close(); fs.rmSync(SOCK, {force: true}); process.exit(0);
  });
  const startedAt = Date.now();
}
