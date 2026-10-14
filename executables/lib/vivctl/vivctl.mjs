#!/usr/bin/env node
// vivctl: manage Vivaldi tabs and tab stacks from the command line.
//
// One file, three roles, chosen by the first argument:
//   daemon     starts Vivaldi on a private CDP pipe and serves a fixed set of
//              operations on a unix socket (started for you by `vivctl start`)
//   <anything> a client: sends one request to the daemon and prints the answer
//
// Why a daemon: Vivaldi's tab stacks are only reachable through its private UI
// APIs (vivaldi.tabsPrivate), which exist inside the browser's own UI page. The
// only way in from outside is the Chrome DevTools Protocol. The pipe variant of
// it (--remote-debugging-pipe) opens no network port at all: only the process
// that spawned the browser holds the two file descriptors. So the daemon is the
// sole holder, and everything else gets the whitelist below, never raw CDP.
// See README.md in this directory for the threat model.

import {spawn} from 'node:child_process';
import net from 'node:net';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const HOME = os.homedir();
const PROFILE = process.env.VIVCTL_PROFILE || path.join(HOME, 'Library/Application Support/Vivaldi-Ctl');
const STATE = process.env.VIVCTL_HOME || path.join(HOME, '.vivctl');
const SOCK = path.join(STATE, 'vivctl.sock');
const LOG = path.join(STATE, 'daemon.log');
const BROWSER = process.env.VIVALDI_BIN || '/Applications/Vivaldi.app/Contents/MacOS/Vivaldi';

const COLORS = {grey: 'color1', blue: 'color2', red: 'color3', yellow: 'color4', green: 'color5',
  pink: 'color6', purple: 'color7', teal: 'color8', orange: 'color9'};
const COLOR_NAME = Object.fromEntries(Object.entries(COLORS).map(([k, v]) => [v, k]));
// Access control: the daemon starts locked and a Touch ID check opens it for a lease.
const AUTH_OFF = process.env.VIVCTL_AUTH === 'off';
const AUTH_BIN = process.env.VIVCTL_AUTH_BIN || '';
const LEASE_MS = (Number(process.env.VIVCTL_LEASE_MINUTES) || 60) * 60000;
const OPEN_OPS = new Set(['ping', 'unlock', 'lock']); // the only operations that work while locked
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

class UserError extends Error {}

function checkAuthSetup() {
  if (AUTH_OFF) return;
  if (!AUTH_BIN || !fs.existsSync(AUTH_BIN)) {
    throw new UserError('the Touch ID helper is missing, so the daemon would run unprotected and refuses to start.\n'
      + 'Run vivctl through the wrapper in executables/macbin (it builds the helper), or set VIVCTL_AUTH=off to run without the lock.');
  }
}

// Titles and URLs are all `tabs` returns. Query and fragment are where tokens live
// (magic links, reset links), so they are cut off and only marked as present.
function stripUrl(u) {
  try {
    const x = new URL(u);
    return x.origin === 'null' ? `${x.protocol}//${x.host}${x.pathname}` : x.origin + x.pathname
      + (x.search ? '?...' : '') + (x.hash ? '#...' : '');
  } catch { return ''; }
}

// ---------------------------------------------------------------- validation
function asInt(v, what) {
  if (!Number.isInteger(v)) throw new UserError(`${what} must be an integer tab id`);
  return v;
}
function asTitle(v) {
  if (typeof v !== 'string' || v.length < 1 || v.length > 100 || /[\u0000-\u001f]/.test(v)) {
    throw new UserError('title must be 1 to 100 printable characters');
  }
  return v;
}
function asColor(v) {
  const key = String(v).toLowerCase();
  if (COLORS[key]) return COLORS[key];
  if (COLOR_NAME[key]) return key;
  throw new UserError(`unknown color "${v}", use one of: ${Object.keys(COLORS).join(', ')}`);
}
function asUrl(v) {
  let u;
  try { u = new URL(v); } catch { throw new UserError(`not a URL: ${v}`); }
  if (u.protocol !== 'http:' && u.protocol !== 'https:') throw new UserError(`only http(s) URLs are allowed: ${v}`);
  return u.href;
}

// -------------------------------------------------------------------- daemon
function log(msg) {
  try { fs.appendFileSync(LOG, `${new Date().toISOString()} ${msg}\n`); } catch { /* logging must never kill the daemon */ }
}

// Code that runs inside Vivaldi's UI page. Every operation body is a fixed
// string; caller input only ever arrives as JSON in `P`, never as code.
const PRE = `
const q=()=>new Promise(r=>chrome.tabs.query({},r));
const ext=t=>{try{return JSON.parse(t.vivExtData||"{}")}catch{return {}}};
const wait=ms=>new Promise(r=>setTimeout(r,ms));
const TW=["target-is-tab","do-not-reparent","on"];
`;

const UI = {
  tabs: `
    return (await q()).map(t=>{const e=ext(t);return {id:t.id,windowId:t.windowId,active:t.active,pinned:t.pinned,
      title:t.title||"",url:t.url||t.pendingUrl||"",group:e.group,groupTitle:e.fixedGroupTitle,groupColor:e.groupColor}})`,
  open: `
    const t=await new Promise(r=>chrome.tabs.create({url:P.url,active:P.focus,windowId:P.windowId},r));
    await wait(300); return t.id`,
  stack: `
    let all=await q(); const first=all.find(t=>t.id===P.first);
    if(!first) throw new Error("no such tab: "+P.first);
    let group=ext(first).group;
    for(const id of P.others){
      if(!all.find(t=>t.id===id)) throw new Error("no such tab: "+id);
      const r=await vivaldi.tabsPrivate.move({tabIds:[id],target:ext(first).ext_id,windowId:first.windowId,
        tweaks:group?TW:[...TW,"create-group"],debug:"vivctl"});
      if(!r.success) throw new Error("Vivaldi refused to move tab "+id);
      await wait(300);
      all=await q(); group=ext(all.find(t=>t.id===P.first)).group||r.group||group;
    }
    if(!group) throw new Error("tab "+P.first+" is not in a stack");
    if(P.title!==undefined||P.color!==undefined){
      const pr={groupExtId:group}; if(P.title!==undefined) pr.groupTitle=P.title; if(P.color!==undefined) pr.groupColor=P.color;
      await vivaldi.tabsPrivate.setGroupProperties(pr);
    }
    return group`,
  props: `
    const pr={groupExtId:P.group}; if(P.title!==undefined) pr.groupTitle=P.title; if(P.color!==undefined) pr.groupColor=P.color;
    await vivaldi.tabsPrivate.setGroupProperties(pr); return true`,
  unstack: `await vivaldi.tabsPrivate.unstack(P.group); return true`,
  close: `await new Promise(r=>chrome.tabs.remove(P.ids,r)); return P.ids`,
};

async function daemon() {
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

  // CDP over a pipe: JSON messages separated by NUL.
  let buf = '', seq = 0;
  const pending = new Map();
  fromB.on('data', d => {
    buf += d;
    let i;
    while ((i = buf.indexOf('\0')) >= 0) {
      const m = JSON.parse(buf.slice(0, i)); buf = buf.slice(i + 1);
      const p = pending.get(m.id); pending.delete(m.id);
      if (p) m.error ? p.reject(new Error(m.error.message)) : p.resolve(m.result);
    }
  });
  const cdp = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
    const id = ++seq; pending.set(id, {resolve, reject});
    toB.write(JSON.stringify({id, method, params, sessionId}) + '\0');
  });

  let session = null;
  async function uiSession() {
    const {targetInfos} = await cdp('Target.getTargets');
    const ui = targetInfos.find(t => t.type === 'app' && t.url.endsWith('/window.html'));
    if (!ui) throw new UserError('Vivaldi has no open window yet');
    if (session?.targetId !== ui.targetId) {
      const r = await cdp('Target.attachToTarget', {targetId: ui.targetId, flatten: true});
      session = {targetId: ui.targetId, sessionId: r.sessionId};
    }
    return session.sessionId;
  }
  async function inUI(name, params = {}) {
    const sid = await uiSession();
    const r = await cdp('Runtime.evaluate', {
      expression: `(async()=>{${PRE}const P=${JSON.stringify(params)};${UI[name]}})()`,
      awaitPromise: true, returnByValue: true}, sid);
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description?.split('\n')[0] || 'UI call failed');
    return r.result.value;
  }

  // ------------------------------------------------------------------- ops
  const listTabs = () => inUI('tabs');
  function stacksOf(tabs) {
    const m = new Map();
    for (const t of tabs) {
      if (!t.group) continue;
      const s = m.get(t.group) || {id: t.group, title: '', color: '', tabs: []};
      s.title ||= t.groupTitle || ''; s.color ||= COLOR_NAME[t.groupColor] || t.groupColor || '';
      s.tabs.push(t.id); m.set(t.group, s);
    }
    return [...m.values()];
  }
  async function resolveStack(ref, {optional = false} = {}) {
    const stacks = stacksOf(await listTabs());
    const r = String(ref).toLowerCase();
    let hit = stacks.filter(s => s.title.toLowerCase() === r);
    if (!hit.length && r.length >= 8) hit = stacks.filter(s => s.id.startsWith(r));
    if (hit.length > 1) throw new UserError(`"${ref}" matches ${hit.length} stacks, use the id from \`vivctl stacks\``);
    if (!hit.length && !optional) throw new UserError(`no stack "${ref}"`);
    return hit[0];
  }
  const props = p => ({...(p.title !== undefined && {title: asTitle(p.title)}), ...(p.color !== undefined && {color: asColor(p.color)})});

  // The lease lives only in this process. Expiry is checked on every request, no timer.
  let leaseUntil = AUTH_OFF ? Infinity : 0, unlocking = null;
  const minutesLeft = () => Math.ceil(Math.max(0, leaseUntil - Date.now()) / 60000);
  const isLocked = () => leaseUntil <= Date.now();
  const lockState = () => ({locked: isLocked(), minutesLeft: leaseUntil === Infinity ? null : minutesLeft(), authOff: AUTH_OFF});
  async function unlock() {
    if (!isLocked()) return lockState();
    // The daemon runs the check itself, so a client cannot claim a success it did not get.
    unlocking ||= new Promise(resolve => {
      const h = spawn(AUTH_BIN, ['Allow vivctl to control Vivaldi'], {stdio: ['ignore', 'ignore', 'pipe']});
      let err = '';
      h.stderr.on('data', d => { err += d; });
      h.on('error', e => resolve({code: -1, err: e.message}));
      h.on('exit', code => resolve({code, err}));
    }).finally(() => { unlocking = null; });
    const {code, err} = await unlocking;
    if (code !== 0) { log(`unlock refused (code ${code})`); throw new UserError(`unlock failed: ${err.trim() || `helper exited with ${code}`}`); }
    leaseUntil = Date.now() + LEASE_MS;
    log(`unlocked for ${LEASE_MS / 60000} minutes`);
    return lockState();
  }

  const OPS = {
    ping: async () => ({profile: PROFILE, pid: process.pid, ready: await uiSession().then(() => true, () => false), ...lockState()}),
    unlock,
    lock: async () => { if (!AUTH_OFF) { leaseUntil = 0; log('locked'); } return lockState(); },
    tabs: async () => (await listTabs()).map(t => ({...t, url: stripUrl(t.url)})),
    stacks: async () => stacksOf(await listTabs()),
    open: async p => {
      const urls = (p.urls || []).map(asUrl);
      if (!urls.length) throw new UserError('give at least one URL');
      const target = p.stack ? await resolveStack(p.stack, {optional: true}) : undefined;
      if (p.stack && !target && urls.length < 2) {
        throw new UserError(`no stack "${p.stack}"; give two or more URLs to create it, a stack needs two tabs`);
      }
      let windowId;
      if (target) windowId = (await listTabs()).find(t => t.id === target.tabs[0])?.windowId;
      const ids = [];
      for (const [i, url] of urls.entries()) ids.push(await inUI('open', {url, focus: !!p.focus && i === urls.length - 1, windowId}));
      if (target) {
        await inUI('stack', {first: target.tabs[0], others: ids, ...props(p)});
        return {tabs: ids, stack: target.id};
      }
      if (p.stack) {
        const group = await inUI('stack', {first: ids[0], others: ids.slice(1), title: asTitle(p.stack), ...props({color: p.color})});
        return {tabs: ids, stack: group};
      }
      return {tabs: ids};
    },
    stack: async p => {
      const tabs = (p.tabs || []).map(t => asInt(t, 'tab'));
      const into = p.into ? await resolveStack(p.into) : undefined;
      if (!into && tabs.length < 2) throw new UserError('a stack needs at least two tabs, or use --into <stack>');
      if (!tabs.length) throw new UserError('give at least one tab id');
      const group = await inUI('stack', into
        ? {first: into.tabs[0], others: tabs, ...props(p)}
        : {first: tabs[0], others: tabs.slice(1), ...props(p)});
      return {stack: group};
    },
    title: async p => (await inUI('props', {group: (await resolveStack(p.stack)).id, title: asTitle(p.title)}), {}),
    color: async p => (await inUI('props', {group: (await resolveStack(p.stack)).id, color: asColor(p.color)}), {}),
    unstack: async p => (await inUI('unstack', {group: (await resolveStack(p.stack)).id}), {}),
    'close-stack': async p => ({closed: await inUI('close', {ids: (await resolveStack(p.stack)).tabs})}),
    close: async p => ({closed: await inUI('close', {ids: (p.tabs || []).map(t => asInt(t, 'tab'))})}),
    quit: async () => { await cdp('Browser.close'); return {}; },
  };

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
          if (!OPEN_OPS.has(req.op) && isLocked()) {
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

// -------------------------------------------------------------------- client
function request(req) {
  return new Promise((resolve, reject) => {
    const c = net.connect(SOCK);
    let data = '';
    c.on('error', e => reject(e.code === 'ENOENT' || e.code === 'ECONNREFUSED'
      ? new UserError('daemon is not running, start it with: vivctl start') : e));
    c.on('connect', () => c.write(JSON.stringify(req) + '\n'));
    c.on('data', d => { data += d; });
    c.on('end', () => {
      const m = JSON.parse(data);
      m.ok ? resolve(m.result) : reject(m.user ? new UserError(m.error) : new Error(m.error));
    });
  });
}

function parseArgs(argv) {
  const valued = new Set(['title', 'color', 'into', 'stack']), flags = new Set(['json', 'focus']);
  const out = {pos: [], opt: {}};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const k = a.slice(2);
      if (valued.has(k)) { if (i + 1 >= argv.length) throw new UserError(`--${k} needs a value`); out.opt[k] = argv[++i]; }
      else if (flags.has(k)) out.opt[k] = true;
      else throw new UserError(`unknown option --${k}`);
    } else out.pos.push(a);
  }
  return out;
}
const ids = pos => pos.map(s => { if (!/^\d+$/.test(s)) throw new UserError(`not a tab id: ${s}`); return Number(s); });
const lockLine = r => r.authOff ? 'lock: off (VIVCTL_AUTH=off)'
  : r.locked ? 'locked, run `vivctl unlock` (Touch ID)' : `unlocked, ${r.minutesLeft} min left`;
const clip = (s, n) => (s.length > n ? s.slice(0, n - 1) + '~' : s);

const HELP = `vivctl: manage Vivaldi tabs and tab stacks

  vivctl start | stop | status        run Vivaldi under the control daemon
  vivctl unlock | lock                Touch ID opens every other command for a while (default 60 min)
  vivctl tabs [--json]                list tabs with their stack (query and fragment of URLs are cut off)
  vivctl stacks [--json]              list stacks
  vivctl open URL... [--stack NAME] [--color C] [--focus]
                                      open tabs; --stack joins NAME, or creates it from 2+ URLs
  vivctl stack TABID... [--into STACK] [--title T] [--color C]
                                      stack tabs (first tab defines the stack), or add to one
  vivctl title STACK TITLE            rename a stack
  vivctl color STACK COLOR            ${Object.keys(COLORS).join(' ')}
  vivctl unstack STACK                dissolve a stack, keep the tabs
  vivctl close-stack STACK            close a stack with all its tabs
  vivctl close TABID...               close tabs

STACK is a title (case-insensitive) or a stack id (8+ leading characters).`;

async function client(cmd, argv) {
  const {pos, opt} = parseArgs(argv);
  const out = r => console.log(opt.json ? JSON.stringify(r, null, 1) : r);
  switch (cmd) {
    case 'status': {
      const r = await request({op: 'ping'});
      return out(opt.json ? r : `running (pid ${r.pid}, ${r.ready ? 'ready' : 'no window yet'})\n${lockLine(r)}\nprofile: ${r.profile}`);
    }
    case 'tabs': {
      const t = await request({op: 'tabs'});
      return opt.json ? out(t) : t.forEach(x => console.log(
        `${String(x.id).padEnd(11)} ${clip(x.groupTitle || (x.group ? x.group.slice(0, 8) : '-'), 16).padEnd(16)} ${clip(x.title, 40).padEnd(40)} ${clip(x.url, 70)}`));
    }
    case 'stacks': {
      const s = await request({op: 'stacks'});
      return opt.json ? out(s) : s.forEach(x => console.log(`${x.id.slice(0, 8)}  ${(x.color || '-').padEnd(7)} ${(x.title || '(untitled)').padEnd(24)} tabs: ${x.tabs.join(' ')}`));
    }
    case 'open': return out(await request({op: 'open', urls: pos, stack: opt.stack, color: opt.color, focus: opt.focus}));
    case 'stack': return out(await request({op: 'stack', tabs: ids(pos), into: opt.into, title: opt.title, color: opt.color}));
    case 'title': if (pos.length !== 2) throw new UserError('usage: vivctl title STACK TITLE'); return out(await request({op: 'title', stack: pos[0], title: pos[1]}));
    case 'color': if (pos.length !== 2) throw new UserError('usage: vivctl color STACK COLOR'); return out(await request({op: 'color', stack: pos[0], color: pos[1]}));
    case 'unstack': case 'close-stack':
      if (pos.length !== 1) throw new UserError(`usage: vivctl ${cmd} STACK`);
      return out(await request({op: cmd, stack: pos[0]}));
    case 'close': return out(await request({op: 'close', tabs: ids(pos)}));
    case 'unlock': { const r = await request({op: 'unlock'}); return out(opt.json ? r : lockLine(r)); }
    case 'lock': { const r = await request({op: 'lock'}); return out(opt.json ? r : lockLine(r)); }
    case 'stop': await request({op: 'quit'}); return console.log('Vivaldi is closing');
    case 'start': return start();
    default: throw new UserError(cmd ? `unknown command "${cmd}"\n\n${HELP}` : HELP);
  }
}

async function start() {
  checkAuthSetup();
  if (await request({op: 'ping'}).then(() => true, () => false)) return console.log('already running');
  fs.mkdirSync(STATE, {recursive: true, mode: 0o700});
  if (!fs.existsSync(PROFILE)) throw new UserError(`profile directory not found: ${PROFILE}\nset VIVCTL_PROFILE or create it first`);
  const out = fs.openSync(LOG, 'a');
  const d = spawn(process.execPath, [fileURLToPath(import.meta.url), 'daemon'], {detached: true, stdio: ['ignore', out, out]});
  d.unref();
  for (let i = 0; i < 60; i++) {
    await new Promise(r => setTimeout(r, 500));
    const r = await request({op: 'ping'}).catch(() => null);
    if (r?.ready) return console.log(`started (pid ${r.pid})\n${lockLine(r)}\nprofile: ${r.profile}`);
  }
  throw new UserError(`daemon did not become ready, see ${LOG}`);
}

const [cmd, ...rest] = process.argv.slice(2);
try {
  cmd === 'daemon' ? await daemon() : await client(cmd, rest);
} catch (e) {
  console.error(`vivctl: ${e instanceof UserError ? e.message : e.stack || e.message}`);
  process.exit(1);
}
