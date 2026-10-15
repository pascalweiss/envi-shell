// Shared by the daemon and the client: configuration, errors, input validation, the log and
// the socket the two talk over.

import net from 'node:net';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

export const HOME = os.homedir();
export const PROFILE = process.env.VIVCTL_PROFILE || path.join(HOME, 'Library/Application Support/Vivaldi-Ctl');
export const STATE = process.env.VIVCTL_HOME || path.join(HOME, '.vivctl');
export const SOCK = path.join(STATE, 'vivctl.sock');
export const LOG = path.join(STATE, 'daemon.log');
// macOS caps a unix socket path at 104 bytes; a longer VIVCTL_HOME would fail deep in listen().
export const SOCK_MAX = 103;
export const SOURCE_PROFILE = process.env.VIVCTL_SOURCE_PROFILE || path.join(HOME, 'Library/Application Support/Vivaldi');
export const BROWSER = process.env.VIVALDI_BIN || '/Applications/Vivaldi.app/Contents/MacOS/Vivaldi';

export const COLORS = {grey: 'color1', blue: 'color2', red: 'color3', yellow: 'color4', green: 'color5',
  pink: 'color6', purple: 'color7', teal: 'color8', orange: 'color9'};
export const COLOR_NAME = Object.fromEntries(Object.entries(COLORS).map(([k, v]) => [v, k]));
// Access control: the daemon starts locked and a Touch ID check opens it for a lease.
export const AUTH_OFF = process.env.VIVCTL_AUTH === 'off';
export const AUTH_BIN = process.env.VIVCTL_AUTH_BIN || '';
export const LEASE_MS = (Number(process.env.VIVCTL_LEASE_MINUTES) || 60) * 60000;
// Hosts whose pages the page operations refuse (comma separated suffixes). Empty by default.
export const DENY = (process.env.VIVCTL_DENY || '').split(',').map(x => x.trim().toLowerCase()).filter(Boolean);
export const OPEN_OPS = new Set(['ping', 'unlock', 'lock']); // the only operations that work while locked

export class UserError extends Error {}
// Vivaldi is up, but every window is closed (on macOS it keeps running like that).
export class NoWindow extends UserError {}

export const hostDenied = u => {
  try { const h = new URL(u).hostname.toLowerCase(); return DENY.some(d => h === d || h.endsWith('.' + d)); } catch { return false; }
};
export const KEYS = {Enter: 13, Tab: 9, Escape: 27, Backspace: 8, Space: 32, ArrowLeft: 37, ArrowUp: 38, ArrowRight: 39,
  ArrowDown: 40, PageUp: 33, PageDown: 34, Home: 36, End: 35};

export function checkAuthSetup() {
  if (AUTH_OFF) return;
  if (!AUTH_BIN || !fs.existsSync(AUTH_BIN)) {
    throw new UserError('the Touch ID helper is missing, so the daemon would run unprotected and refuses to start.\n'
      + 'Run vivctl through the wrapper in executables/macbin (it builds the helper), or set VIVCTL_AUTH=off to run without the lock.');
  }
}

// Titles and URLs are all `tabs` returns. Query and fragment are where tokens live
// (magic links, reset links), so they are cut off and only marked as present.
export function stripUrl(u) {
  try {
    const x = new URL(u);
    return x.origin === 'null' ? `${x.protocol}//${x.host}${x.pathname}` : x.origin + x.pathname
      + (x.search ? '?...' : '') + (x.hash ? '#...' : '');
  } catch { return ''; }
}

// ---------------------------------------------------------------- validation
export function asInt(v, what) {
  if (!Number.isInteger(v)) throw new UserError(`${what} must be an integer tab id`);
  return v;
}
export function asTitle(v) {
  if (typeof v !== 'string' || v.length < 1 || v.length > 100 || /[\u0000-\u001f]/.test(v)) {
    throw new UserError('title must be 1 to 100 printable characters');
  }
  return v;
}
export function asColor(v) {
  const key = String(v).toLowerCase();
  if (COLORS[key]) return COLORS[key];
  if (COLOR_NAME[key]) return key;
  throw new UserError(`unknown color "${v}", use one of: ${Object.keys(COLORS).join(', ')}`);
}
export function asUrl(v) {
  let u;
  try { u = new URL(v); } catch { throw new UserError(`not a URL: ${v}`); }
  if (u.protocol !== 'http:' && u.protocol !== 'https:') throw new UserError(`only http(s) URLs are allowed: ${v}`);
  return u.href;
}

export function log(msg) {
  try { fs.appendFileSync(LOG, `${new Date().toISOString()} ${msg}\n`); } catch { /* logging must never kill the daemon */ }
}

export function checkSocketPath() {
  if (Buffer.byteLength(SOCK) > SOCK_MAX) {
    throw new UserError(`the socket path ${SOCK} is longer than the ${SOCK_MAX} bytes macOS allows; set VIVCTL_HOME to a shorter directory`);
  }
}

export const sleep = ms => new Promise(r => setTimeout(r, ms));

// Tabs grouped by their stack, as the `stacks` command lists them.
export function stacksOf(tabs) {
  const m = new Map();
  for (const t of tabs) {
    if (!t.group) continue;
    const s = m.get(t.group) || {id: t.group, title: '', color: '', tabs: []};
    s.title ||= t.groupTitle || ''; s.color ||= COLOR_NAME[t.groupColor] || t.groupColor || '';
    s.tabs.push(t.id); m.set(t.group, s);
  }
  return [...m.values()];
}

// One request to the daemon, one answer.
export function request(req) {
  checkSocketPath();
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
