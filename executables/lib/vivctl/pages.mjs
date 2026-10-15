// The web page behind a tab: finding it, running page scripts in an isolated world, and input
// that is checked to arrive.

import {UserError, KEYS, hostDenied, sleep} from './common.mjs';
import {PAGE_LIB, PAGE} from './page-scripts.mjs';

export function pageAccess({cdp, inUI, listTabs}) {
  async function waitLoaded(id) {
    for (let i = 0; i < 50; i++) {
      const st = await inUI('status', {id});
      if (!st) throw new UserError(`no such tab: ${id}`);
      if (st.status === 'complete') return;
      if (st.status === 'unloaded' || st.discarded) throw new UserError(`tab ${id} is not loaded (hibernated); \`vivctl reload ${id}\` loads it`);
      await sleep(300);
    }
  }
  const evalIn = (sessionId, expression, timeoutMs) =>
    cdp('Runtime.evaluate', {expression, returnByValue: true}, sessionId, timeoutMs).then(r => r.result.value);

  // A tab id cannot be mapped to a CDP target directly. Candidates are the page targets with the
  // tab's URL; restored tabs that were never loaded have a target but no renderer and never answer,
  // so each candidate is probed. Waiting stops as soon as as many pages answered as Vivaldi reports
  // loaded tabs with that URL, so a dead candidate costs nothing in the common case. When several
  // loaded pages remain, each gets a marker title for a moment, and the one whose marker shows up
  // on the tab is it.
  async function findPage(tab, tabs) {
    const expected = Math.max(1, tabs.filter(t => t.url === tab.url && t.status !== 'unloaded').length);
    const {targetInfos} = await cdp('Target.getTargets');
    const candidates = targetInfos.filter(t => t.type === 'page' && t.url === tab.url);
    const live = [];
    let done = false;
    const detach = sessionId => cdp('Target.detachFromTarget', {sessionId}).catch(() => {});
    await new Promise(resolve => {
      let left = candidates.length;
      if (!left) resolve();
      for (const t of candidates) {
        (async () => {
          const sessionId = (await cdp('Target.attachToTarget', {targetId: t.targetId, flatten: true}).catch(() => ({}))).sessionId;
          const title = sessionId ? await evalIn(sessionId, 'document.title', 1500).catch(() => null) : null;
          if (title === null || done) { if (sessionId) detach(sessionId); } else live.push({sessionId, title});
          if (--left === 0 || live.length >= expected) resolve();
        })();
      }
    });
    done = true;
    let chosen = live.length === 1 ? live[0] : null;
    if (live.length > 1) {
      const mark = `vivctl-${process.pid}-${Date.now()}-`;
      const old = await Promise.all(live.map((x, i) =>
        evalIn(x.sessionId, `(()=>{const o=document.title;document.title=${JSON.stringify(mark + i)};return o})()`).catch(() => null)));
      try {
        for (let i = 0; i < 20 && !chosen; i++) {
          await sleep(100);
          const now = (await inUI('status', {id: tab.id}))?.title || '';
          chosen = live.find((_, j) => now === mark + j) || null;
        }
      } finally {
        await Promise.all(live.map((x, i) => old[i] === null ? null
          : evalIn(x.sessionId, `document.title=${JSON.stringify(old[i])}`).catch(() => {})));
      }
    }
    live.filter(x => x !== chosen).forEach(x => detach(x.sessionId));
    if (!chosen) {
      throw new UserError(live.length ? 'could not tell which of the pages with this URL belongs to the tab'
        : 'this tab has no loaded page, or it changed while reading; retry, or `vivctl reload` it');
    }
    return chosen.sessionId;
  }

  // Runs fn against the page behind a Vivaldi tab, with scripts in an isolated world.
  async function onPage(tabId, fn) {
    await waitLoaded(tabId);
    const tabs = await listTabs();
    const tab = tabs.find(t => t.id === tabId);
    if (!tab) throw new UserError(`no such tab: ${tabId}`);
    if (hostDenied(tab.url)) throw new UserError('pages of this host are blocked (VIVCTL_DENY)');
    const sessionId = await findPage(tab, tabs);
    const send = (m, p) => cdp(m, p, sessionId);
    try {
      // Without focus emulation a tab in the background never has focus, and focus() does nothing.
      await send('Emulation.setFocusEmulationEnabled', {enabled: true}).catch(() => {});
      const {frameTree} = await send('Page.getFrameTree');
      const {executionContextId} = await send('Page.createIsolatedWorld', {frameId: frameTree.frame.id, worldName: 'vivctl'});
      const run = async (code, P = {}) => {
        const r = await send('Runtime.evaluate', {expression: `(()=>{${PAGE_LIB}const P=${JSON.stringify(P)};return ${code}})()`,
          contextId: executionContextId, returnByValue: true, awaitPromise: true});
        if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description?.split('\n')[0] || 'page script failed');
        return r.result.value;
      };
      return await fn({send, run, tab, sessionId});
    } finally {
      cdp('Target.detachFromTarget', {sessionId}).catch(() => {});
    }
  }
  // After an action: give the page a moment to react, then wait while a navigation it started is
  // still loading, so that the next command already sees the new page.
  async function settle(tabId, ms = 150) {
    await sleep(ms);
    for (let i = 0; i < 40; i++) {
      const st = await inUI('status', {id: tabId}).catch(() => null);
      if (!st || st.status !== 'loading') return;
      await sleep(250);
    }
  }

  // Trusted key first; if the page never saw it (Vivaldi drops keyboard input to tabs that are not
  // in front), the same key is dispatched from the page instead. The caller learns which one it was.
  async function pressKey(send, run, key) {
    const code = key === 'Space' ? 'Space' : key, k = key === 'Space' ? ' ' : key;
    await run(PAGE.keyarm);
    for (const type of ['keyDown', 'keyUp']) {
      await send('Input.dispatchKeyEvent', {type, key: k, code, windowsVirtualKeyCode: KEYS[key],
        text: type === 'keyDown' && key === 'Enter' ? '\r' : undefined});
    }
    if (await run(PAGE.keyed)) return {via: 'keyboard'};
    const r = await run(PAGE.jskey, {key: k, code, keyCode: KEYS[key]});
    return {via: 'script', ...(r.submitted && {submitted: true})};
  }

  return {waitLoaded, onPage, settle, pressKey};
}
