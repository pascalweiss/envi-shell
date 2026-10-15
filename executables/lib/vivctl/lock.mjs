// The Touch ID lock: the daemon starts locked, and a check that the daemon runs itself opens it
// for a lease.

import {spawn} from 'node:child_process';
import {AUTH_OFF, AUTH_BIN, LEASE_MS, UserError, log} from './common.mjs';

export function createLock() {
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
  function lock() {
    if (!AUTH_OFF) { leaseUntil = 0; log('locked'); }
    return lockState();
  }

  return {isLocked, lockState, unlock, lock};
}
