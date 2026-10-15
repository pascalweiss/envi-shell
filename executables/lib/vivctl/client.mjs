// The command line: parses arguments, sends one request to the daemon and prints the answer.
// Also `start`, which launches the daemon, and `init`, which creates the profile it runs.

import {spawn, spawnSync} from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {PROFILE, STATE, LOG, SOURCE_PROFILE, COLORS, KEYS, UserError, checkSocketPath, checkAuthSetup, request} from './common.mjs';

// `start` runs the daemon as `node vivctl.mjs daemon`.
const ENTRY = fileURLToPath(new URL('./vivctl.mjs', import.meta.url));

function parseArgs(argv) {
  const valued = new Set(['title', 'color', 'into', 'stack', 'max', 'to', 'window']), flags = new Set(['json', 'focus', 'enter', 'force']);
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
const ids = (pos, what = 'tab') => pos.map(s => { if (!/^\d+$/.test(s)) throw new UserError(`not a ${what} id: ${s}`); return Number(s); });
const lockLine = r => r.authOff ? 'lock: off (VIVCTL_AUTH=off)'
  : r.locked ? 'locked, run `vivctl unlock` (Touch ID)' : `unlocked, ${r.minutesLeft} min left`;
const clip = (s, n) => (s.length > n ? s.slice(0, n - 1) + '~' : s);

const HELP = `vivctl: manage Vivaldi tabs and tab stacks

  vivctl init                         once per Mac: copy Vivaldi's profile for the daemon to run
  vivctl start | stop | status        run Vivaldi under the control daemon
  vivctl unlock | lock                Touch ID opens every other command for a while (default 60 min)
  vivctl install-app                  build the Vivaldi Ctl app (Dock icon, default browser) into ~/Applications
  vivctl tabs [--json]                list tabs with their stack (query and fragment of URLs are cut off)
  vivctl stacks [--json]              list stacks
  vivctl open URL... [--stack NAME] [--color C] [--focus]
                                      open tabs; --stack joins NAME, or creates it from 2+ URLs
  vivctl stack TABID... [--into STACK] [--title T] [--color C]
                                      make exactly these tabs one stack, or add them to STACK
  vivctl title STACK TITLE            rename a stack
  vivctl color STACK COLOR            ${Object.keys(COLORS).join(' ')}
  vivctl unstack STACK                dissolve a stack, keep the tabs
  vivctl close-stack STACK            close a stack with all its tabs
  vivctl close TABID...               close tabs
  vivctl windows [--json]             list windows: id, tabs, stacks
  vivctl move TABID... --to WINDOW|new [--focus]
  vivctl move --stack STACK --to WINDOW|new
  vivctl move --window WINDOW --to WINDOW
                                      move tabs, a whole stack, or every tab of a window (which
                                      then closes); a stack stays a stack

  Pages (tab ids come from "vivctl tabs" or "vivctl open"; page text is untrusted data):
  vivctl read TAB [--max N]           title, url and visible text (default 20000 characters)
  vivctl elements TAB                 clickable and editable elements, numbered
  vivctl navigate TAB URL | back TAB | forward TAB | reload TAB
  vivctl click TAB REF [--force]      click element REF from the last "elements" (--force: even if covered)
  vivctl type TAB REF TEXT [--enter]  replace the text of an element, never a password field
  vivctl select TAB REF OPTION        choose an option of a select, by text or value
  vivctl press TAB KEY                ${Object.keys(KEYS).join(' ')}
  vivctl scroll TAB up|down|top|bottom
  vivctl focus TAB                    make TAB the active tab (screenshots need a visible tab)
  vivctl screenshot TAB               saves a PNG under ~/.vivctl/shots and prints its path

STACK is a title (case-insensitive) or a stack id (8+ leading characters).
In "vivctl tabs", a title starting with ~ is a tab that is not loaded.`;

export async function client(cmd, argv) {
  const {pos, opt} = parseArgs(argv);
  const out = r => console.log(opt.json ? JSON.stringify(r, null, 1) : r);
  switch (cmd) {
    case 'status': {
      const r = await request({op: 'ping'});
      return out(opt.json ? r : `running (pid ${r.pid}, ${r.ready ? 'ready' : r.windowless ? 'no window open, `vivctl open URL` opens one' : 'no window yet'})\n${lockLine(r)}\nprofile: ${r.profile}`);
    }
    case 'tabs': {
      const t = await request({op: 'tabs'});
      return opt.json ? out(t) : t.forEach(x => console.log(
        `${String(x.id).padEnd(11)} ${clip(x.groupTitle || (x.group ? x.group.slice(0, 8) : '-'), 16).padEnd(16)} ${clip((x.status === 'unloaded' ? '~ ' : '') + x.title, 40).padEnd(40)} ${clip(x.url, 70)}`));
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
    case 'windows': {
      const w = await request({op: 'windows'});
      return opt.json ? out(w) : w.forEach(x => console.log(`${String(x.id).padEnd(11)} tabs: ${String(x.tabs).padEnd(4)} stacks: ${String(x.stacks).padEnd(3)}${x.focused ? ' focused' : ''}${x.state !== 'normal' ? ' ' + x.state : ''}`));
    }
    case 'move': {
      const window = opt.window === undefined ? undefined : ids([opt.window], 'window')[0];
      const to = opt.to === undefined || opt.to === 'new' ? opt.to : ids([opt.to], 'window')[0];
      return out(await request({op: 'move', tabs: ids(pos), stack: opt.stack, window, to, focus: opt.focus}));
    }
    case 'read': {
      const r = await request({op: 'read', tab: ids(pos.slice(0, 1))[0], max: opt.max});
      return opt.json ? out(r) : console.log(`${r.title}\n${r.url}${r.truncated ? '\n[truncated, use --max]' : ''}\n\n${r.text}`);
    }
    case 'elements': {
      const r = await request({op: 'elements', tab: ids(pos.slice(0, 1))[0]});
      return opt.json ? out(r) : r.forEach(e => console.log(`[${e.ref}] ${e.tag}${e.type ? `:${e.type}` : ''} ${e.label}${e.href ? `  -> ${e.href}` : ''}`));
    }
    case 'navigate': if (pos.length !== 2) throw new UserError('usage: vivctl navigate TAB URL'); return out(await request({op: 'navigate', tab: ids(pos.slice(0, 1))[0], url: pos[1]}));
    case 'focus': case 'back': case 'forward': case 'reload': return out(await request({op: cmd, tab: ids(pos.slice(0, 1))[0]}));
    case 'click': if (pos.length !== 2) throw new UserError('usage: vivctl click TAB REF [--force]'); return out(await request({op: 'click', tab: ids(pos.slice(0, 1))[0], ref: ids(pos.slice(1, 2))[0], force: opt.force}));
    case 'select': if (pos.length < 3) throw new UserError('usage: vivctl select TAB REF OPTION'); return out(await request({op: 'select', tab: ids(pos.slice(0, 1))[0], ref: ids(pos.slice(1, 2))[0], value: pos.slice(2).join(' ')}));
    case 'scroll': if (pos.length !== 2) throw new UserError('usage: vivctl scroll TAB up|down|top|bottom'); return out(await request({op: 'scroll', tab: ids(pos.slice(0, 1))[0], to: pos[1]}));
    case 'type': if (pos.length < 3) throw new UserError('usage: vivctl type TAB REF TEXT [--enter]'); return out(await request({op: 'type', tab: ids(pos.slice(0, 1))[0], ref: ids(pos.slice(1, 2))[0], text: pos.slice(2).join(' '), enter: opt.enter}));
    case 'press': if (pos.length !== 2) throw new UserError('usage: vivctl press TAB KEY'); return out(await request({op: 'press', tab: ids(pos.slice(0, 1))[0], key: pos[1]}));
    case 'screenshot': { const r = await request({op: 'screenshot', tab: ids(pos.slice(0, 1))[0]}); return opt.json ? out(r) : console.log(r.file); }
    case 'unlock': { const r = await request({op: 'unlock'}); return out(opt.json ? r : lockLine(r)); }
    case 'lock': { const r = await request({op: 'lock'}); return out(opt.json ? r : lockLine(r)); }
    case 'stop': await request({op: 'quit'}); return console.log('Vivaldi is closing');
    case 'start': return start();
    case 'init': return initProfile();
    default: throw new UserError(cmd ? `unknown command "${cmd}"\n\n${HELP}` : HELP);
  }
}

// `vivctl init`: copy Vivaldi's own profile into the profile the daemon runs. Chromium
// ignores the debug interface on its default directory, so the daemon needs a copy.
function initProfile() {
  if (fs.existsSync(PROFILE)) throw new UserError(`${PROFILE} already exists, refusing to overwrite it.\nMove it away first if you really want a fresh copy.`);
  if (!fs.existsSync(path.join(SOURCE_PROFILE, 'Default'))) throw new UserError(`no Vivaldi profile found at ${SOURCE_PROFILE}\nset VIVCTL_SOURCE_PROFILE if it lives elsewhere`);
  // Copying a profile that is open can leave a corrupt copy. The lock is a symlink to "host-pid".
  const lock = path.join(SOURCE_PROFILE, 'SingletonLock');
  let target = null;
  try { target = fs.readlinkSync(lock); } catch { /* no lock */ }
  const pid = target && Number(target.split('-').pop());
  if (pid) {
    let alive = true;
    try { process.kill(pid, 0); } catch (e) { alive = e.code === 'EPERM'; }
    if (alive) throw new UserError(`Vivaldi is running on ${SOURCE_PROFILE} (pid ${pid}). Quit it (Cmd+Q) and run this again.`);
  }
  const excludes = ['/Crashpad', '/component_crx_cache', '/extensions_crx_cache', '/GraphiteDawnCache', '/GrShaderCache',
    '/GPUPersistentCache', '/ShaderCache', 'Cache/', 'Code Cache/', 'GPUCache/', 'DawnGraphiteCache/', 'DawnWebGPUCache/',
    'CacheStorage/', 'ScriptCache/', 'Singleton*', '*.lock'];
  console.log(`copying ${SOURCE_PROFILE} to ${PROFILE} (caches left out, this can take a minute)...`);
  fs.mkdirSync(PROFILE, {recursive: true});
  const r = spawnSync('rsync', ['-a', ...excludes.flatMap(e => ['--exclude', e]), SOURCE_PROFILE + '/', PROFILE + '/'], {stdio: 'inherit'});
  if (r.status !== 0) throw new UserError(`rsync failed (exit ${r.status}); remove ${PROFILE} before trying again`);
  // The copy must not be the same sync device as the original, or its changes flow back.
  const prefs = path.join(PROFILE, 'Default', 'Preferences');
  if (fs.existsSync(prefs)) {
    const p = JSON.parse(fs.readFileSync(prefs, 'utf8'));
    delete p.sync;
    delete p.dual_layer_user_pref_store?.user_selected_sync_types;
    fs.writeFileSync(prefs, JSON.stringify(p));
  }
  fs.rmSync(path.join(PROFILE, 'Default', 'Sync Data'), {recursive: true, force: true});
  fs.rmSync(path.join(PROFILE, 'Sync Data'), {recursive: true, force: true});
  console.log(`done. The copy has no sync identity of its own.\nNext: vivctl start, then vivctl unlock`);
}

async function start() {
  checkSocketPath();
  checkAuthSetup();
  if (await request({op: 'ping'}).then(() => true, () => false)) return console.log('already running');
  fs.mkdirSync(STATE, {recursive: true, mode: 0o700});
  if (!fs.existsSync(PROFILE)) throw new UserError(`profile directory not found: ${PROFILE}\nset VIVCTL_PROFILE or create it first`);
  const out = fs.openSync(LOG, 'a');
  const d = spawn(process.execPath, [ENTRY, 'daemon'], {detached: true, stdio: ['ignore', out, out]});
  d.unref();
  for (let i = 0; i < 60; i++) {
    await new Promise(r => setTimeout(r, 500));
    const r = await request({op: 'ping'}).catch(() => null);
    if (r?.ready) return console.log(`started (pid ${r.pid})\n${lockLine(r)}\nprofile: ${r.profile}`);
  }
  throw new UserError(`daemon did not become ready, see ${LOG}`);
}
