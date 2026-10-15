// The connection to Vivaldi: CDP over the pipe the daemon holds, and calls into Vivaldi's own UI
// pages, where tabs and stacks are reachable.

import {UserError, NoWindow, log, sleep, stacksOf} from './common.mjs';
import {PRE, UI} from './ui-scripts.mjs';

export function connect(toB, fromB) {
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
  const cdp = (method, params = {}, sessionId, timeoutMs = 15000) => new Promise((resolve, reject) => {
    const id = ++seq;
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`${method} timed out`)); }, timeoutMs);
    pending.set(id, {resolve: v => { clearTimeout(timer); resolve(v); }, reject: e => { clearTimeout(timer); reject(e); }});
    toB.write(JSON.stringify({id, method, params, sessionId}) + '\0');
  });

  // One attached session per UI page, reattached when the page is a new one.
  const sessions = {};
  async function attach(kind, target) {
    if (sessions[kind]?.targetId !== target.targetId) {
      const r = await cdp('Target.attachToTarget', {targetId: target.targetId, flatten: true});
      sessions[kind] = {targetId: target.targetId, sessionId: r.sessionId};
    }
    return sessions[kind].sessionId;
  }
  // window.html is the UI of a browser window and only exists while one is open; main.html is
  // Vivaldi's background page and stays while Vivaldi runs.
  async function uiTargets() {
    const {targetInfos} = await cdp('Target.getTargets');
    const app = suffix => targetInfos.find(t => t.type === 'app' && t.url.endsWith(suffix));
    return {win: app('/window.html'), bg: app('/main.html')};
  }
  // With every window closed, the background page opens a new one (with Vivaldi's start page).
  async function ensureWindow() {
    let {win, bg} = await uiTargets();
    if (win) return win;
    if (!bg) throw new UserError('Vivaldi is not ready yet');
    await inUI('newWindow', {}, {bg: true});
    for (let i = 0; i < 40 && !win; i++) { await sleep(250); ({win} = await uiTargets()); }
    if (!win) throw new Error('a window was opened, but its UI did not come up');
    log('opened a window, none was open');
    return win;
  }
  async function uiSession({create = false} = {}) {
    let ui;
    if (create) ui = await ensureWindow();
    else {
      const {win, bg} = await uiTargets();
      if (!win) throw bg ? new NoWindow('Vivaldi has no open window; `vivctl open URL` opens one') : new UserError('Vivaldi has no open window yet');
      ui = win;
    }
    return attach('window', ui);
  }
  // The background page outlives every window. Closing tabs runs there: closing the last tab
  // closes the window, and a call running in that window's UI page would never return.
  async function bgSession() {
    const {bg} = await uiTargets();
    if (!bg) throw new UserError('Vivaldi is not ready yet');
    return attach('background', bg);
  }
  async function inUI(name, params = {}, {create = false, bg = false} = {}) {
    const sid = bg ? await bgSession() : await uiSession({create});
    const r = await cdp('Runtime.evaluate', {
      expression: `(async()=>{${PRE}const P=${JSON.stringify(params)};${UI[name]}})()`,
      awaitPromise: true, returnByValue: true}, sid);
    if (r.exceptionDetails) {
      const msg = r.exceptionDetails.exception?.description?.split('\n')[0] || 'UI call failed';
      const user = msg.match(/\[user\] (.*)$/);
      throw user ? new UserError(user[1]) : new Error(msg);
    }
    return r.result.value;
  }

  // ------------------------------------------------------------------- ops
  // No window means no tabs, which is an answer rather than an error.
  const listTabs = () => inUI('tabs').catch(e => { if (e instanceof NoWindow) return []; throw e; });
  async function resolveStack(ref, {optional = false} = {}) {
    const stacks = stacksOf(await listTabs());
    const r = String(ref).toLowerCase();
    let hit = stacks.filter(s => s.title.toLowerCase() === r);
    if (!hit.length && r.length >= 8) hit = stacks.filter(s => s.id.startsWith(r));
    if (hit.length > 1) throw new UserError(`"${ref}" matches ${hit.length} stacks, use the id from \`vivctl stacks\``);
    if (!hit.length && !optional) throw new UserError(`no stack "${ref}"`);
    return hit[0];
  }

  return {cdp, uiTargets, ensureWindow, inUI, listTabs, resolveStack};
}
