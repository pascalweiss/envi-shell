// The lock: the daemon starts locked, and a check that the daemon runs itself opens it for a
// lease. The check is Touch ID, or the vivctl password for a session without the Mac's screen
// (SSH). The password is vivctl's own, never the login password, and only its scrypt hash is kept.

import {spawn} from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {promisify} from 'node:util';
import {AUTH_OFF, AUTH_BIN, LEASE_MS, STATE, UserError, log} from './common.mjs';

const scrypt = promisify(crypto.scrypt);
const PASSWORD_FILE = path.join(STATE, 'password');
// scrypt cost: about 0.1 s per check on an Apple silicon Mac. maxmem must exceed 128 * N * r.
const KDF = {N: 2 ** 15, r: 8, p: 1, keylen: 32};
const kdf = (pw, salt, k) => scrypt(pw, salt, k.keylen, {N: k.N, r: k.r, p: k.p, maxmem: 256 * k.N * k.r});
export const PASSWORD_MIN = 10;
// After this many wrong passwords in a row the password is refused, right or wrong, for a while.
const MAX_FAILURES = 3;
const BLOCK_MS = 5 * 60000;

export function createLock() {
  // The lease lives only in this process. Expiry is checked on every request, no timer.
  let leaseUntil = AUTH_OFF ? Infinity : 0, touching = null, failures = 0, blockedUntil = 0;
  const minutesLeft = () => Math.ceil(Math.max(0, leaseUntil - Date.now()) / 60000);
  const isLocked = () => leaseUntil <= Date.now();
  const lockState = () => ({locked: isLocked(), minutesLeft: leaseUntil === Infinity ? null : minutesLeft(), authOff: AUTH_OFF,
    password: fs.existsSync(PASSWORD_FILE)});
  const open = how => { leaseUntil = Date.now() + LEASE_MS; log(`unlocked by ${how} for ${LEASE_MS / 60000} minutes`); return lockState(); };

  // The daemon runs the check itself, so a client cannot claim a success it did not get.
  async function touchId(reason) {
    touching ||= new Promise(resolve => {
      const h = spawn(AUTH_BIN, [reason], {stdio: ['ignore', 'ignore', 'pipe']});
      let err = '';
      h.stderr.on('data', d => { err += d; });
      h.on('error', e => resolve({code: -1, err: e.message}));
      h.on('exit', code => resolve({code, err}));
    }).finally(() => { touching = null; });
    const {code, err} = await touching;
    if (code !== 0) { log(`Touch ID refused (code ${code})`); throw new UserError(`unlock failed: ${err.trim() || `helper exited with ${code}`}`); }
  }

  // One check at a time: `unlock` skips the request queue, and parallel guesses must not all be
  // under way before the first failure is counted.
  let checks = Promise.resolve();
  const checkPassword = pw => (checks = checks.catch(() => {}).then(() => verifyPassword(pw)));
  async function verifyPassword(pw) {
    if (Date.now() < blockedUntil) {
      throw new UserError(`too many wrong passwords, the password is refused for ${Math.ceil((blockedUntil - Date.now()) / 60000)} more min (Touch ID still works)`);
    }
    let stored;
    try { stored = JSON.parse(fs.readFileSync(PASSWORD_FILE, 'utf8')); } catch {
      throw new UserError('no vivctl password is set; set one at the Mac with `vivctl set-password` (needs Touch ID)');
    }
    const want = Buffer.from(stored.hash, 'base64');
    const got = await kdf(pw, Buffer.from(stored.salt, 'base64'), {...stored, keylen: want.length});
    if (crypto.timingSafeEqual(got, want)) { failures = 0; return; }
    failures++;
    log(`wrong password (${failures} in a row)`);
    if (failures >= MAX_FAILURES) { failures = 0; blockedUntil = Date.now() + BLOCK_MS; log(`password refused for ${BLOCK_MS / 60000} minutes`); }
    throw new UserError('unlock failed: wrong password');
  }

  async function unlock(req = {}) {
    if (!isLocked()) return lockState();
    if (req.password !== undefined) {
      if (typeof req.password !== 'string') throw new UserError('the password must be a string');
      await checkPassword(req.password);
      return open('password');
    }
    await touchId('Allow vivctl to control Vivaldi');
    return open('Touch ID');
  }

  // Setting, changing or removing the password always takes a fresh Touch ID, also while unlocked:
  // otherwise whoever holds a lease could set a password of their own and keep the browser.
  async function setPassword(req = {}) {
    if (AUTH_OFF) throw new UserError('the lock is off (VIVCTL_AUTH=off), there is nothing a password could open');
    if (!req.remove && (typeof req.password !== 'string' || req.password.length < PASSWORD_MIN)) {
      throw new UserError(`the password needs at least ${PASSWORD_MIN} characters`);
    }
    await touchId(req.remove ? 'Remove the vivctl password' : 'Set the vivctl password');
    if (req.remove) {
      fs.rmSync(PASSWORD_FILE, {force: true});
      log('password removed');
      return {password: false};
    }
    const salt = crypto.randomBytes(16);
    const hash = await kdf(req.password, salt, KDF);
    const tmp = `${PASSWORD_FILE}.${process.pid}`;
    fs.writeFileSync(tmp, JSON.stringify({salt: salt.toString('base64'), hash: hash.toString('base64'), N: KDF.N, r: KDF.r, p: KDF.p}), {mode: 0o600});
    fs.renameSync(tmp, PASSWORD_FILE);
    failures = 0; blockedUntil = 0;
    log('password set');
    return {password: true};
  }

  function lock() {
    if (!AUTH_OFF) { leaseUntil = 0; log('locked'); }
    return lockState();
  }

  return {isLocked, lockState, unlock, lock, setPassword};
}
