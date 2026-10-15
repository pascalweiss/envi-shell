// The whitelist: every operation the daemon serves. Nothing else reaches the browser, and caller
// input only ever reaches it as data.

import fs from 'node:fs';
import path from 'node:path';
import {PROFILE, STATE, KEYS, UserError, asInt, asTitle, asColor, asUrl, stripUrl, hostDenied, stacksOf} from './common.mjs';
import {PAGE} from './page-scripts.mjs';

export function createOps({browser, pages, lock}) {
  const {cdp, uiTargets, inUI, listTabs, resolveStack} = browser;
  const {onPage, settle, pressKey} = pages;
  const {lockState} = lock;
  const props = p => ({...(p.title !== undefined && {title: asTitle(p.title)}), ...(p.color !== undefined && {color: asColor(p.color)})});
  const tabArg = p => asInt(p.tab, 'tab');

  return {
    ping: async () => {
      const {win, bg} = await uiTargets().catch(() => ({}));
      return {profile: PROFILE, pid: process.pid, ready: !!win, windowless: !win && !!bg, ...lockState()};
    },
    unlock: lock.unlock,
    lock: async () => lock.lock(),
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
      for (const [i, url] of urls.entries()) ids.push(await inUI('open', {url, focus: !!p.focus && i === urls.length - 1, windowId}, {create: true}));
      // Vivaldi opens a tab next to the active one and, when that one is in a stack, puts the new
      // tab into it. Taking it out again right away means a tab only ever lands in a stack that was
      // asked for, and no foreign stack can be mistaken for the new one and renamed.
      await inUI('ungroup', {ids});
      if (target) {
        await inUI('stack', {first: target.tabs[0], others: ids, expect: [...target.tabs, ...ids], ...props(p)});
        return {tabs: ids, stack: target.id};
      }
      if (p.stack) {
        const group = await inUI('stack', {first: ids[0], others: ids.slice(1), expect: ids, title: asTitle(p.stack), ...props({color: p.color})});
        return {tabs: ids, stack: group};
      }
      return {tabs: ids};
    },
    stack: async p => {
      const tabs = [...new Set((p.tabs || []).map(t => asInt(t, 'tab')))];
      if (!tabs.length) throw new UserError('give at least one tab id');
      const into = p.into ? await resolveStack(p.into) : undefined;
      if (!into && tabs.length < 2) throw new UserError('a stack needs at least two tabs, or use --into <stack>');
      const all = await listTabs();
      const byId = new Map(all.map(t => [t.id, t]));
      for (const id of tabs) if (!byId.has(id)) throw new UserError(`no such tab: ${id}`);
      if (into) {
        // Tabs from another stack leave it first. The title and color go to the target stack.
        const join = tabs.filter(id => byId.get(id).group !== into.id);
        const elsewhere = join.filter(id => byId.get(id).group);
        if (elsewhere.length) await inUI('ungroup', {ids: elsewhere});
        await inUI('stack', {first: into.tabs[0], others: join, expect: [...into.tabs, ...join], ...props(p)});
        return {stack: into.id};
      }
      // Exactly these tabs become one stack. Their current stack is kept only if it holds nothing
      // else; otherwise they leave their stacks, which keep their remaining tabs, title and color.
      const groups = new Set(tabs.map(id => byId.get(id).group));
      const own = groups.size === 1 ? [...groups][0] : undefined;
      if (own && all.filter(t => t.group === own).length === tabs.length) {
        await inUI('stack', {first: tabs[0], others: [], expect: tabs, ...props(p)});
        return {stack: own};
      }
      const grouped = tabs.filter(id => byId.get(id).group);
      if (grouped.length) await inUI('ungroup', {ids: grouped});
      const group = await inUI('stack', {first: tabs[0], others: tabs.slice(1), expect: tabs, ...props(p)});
      return {stack: group};
    },
    title: async p => { const title = asTitle(p.title); await inUI('props', {group: (await resolveStack(p.stack)).id, title}); return {}; },
    color: async p => { const color = asColor(p.color); await inUI('props', {group: (await resolveStack(p.stack)).id, color}); return {}; },
    unstack: async p => (await inUI('unstack', {group: (await resolveStack(p.stack)).id}), {}),
    'close-stack': async p => ({closed: await inUI('close', {ids: (await resolveStack(p.stack)).tabs}, {bg: true})}),
    close: async p => ({closed: await inUI('close', {ids: (p.tabs || []).map(t => asInt(t, 'tab'))}, {bg: true})}),
    read: p => onPage(tabArg(p), async ({run}) => {
      const max = Math.min(Math.max(Number(p.max) || 20000, 100), 200000);
      const r = await run(PAGE.read);
      return {untrusted: true, title: r.title, url: stripUrl(r.url), truncated: r.text.length > max, text: r.text.slice(0, max)};
    }),
    elements: p => onPage(tabArg(p), async ({run}) =>
      (await run(PAGE.elements)).map(e => ({...e, href: e.href ? stripUrl(e.href) : undefined}))),
    navigate: async p => {
      const id = tabArg(p), url = asUrl(p.url);
      if (hostDenied(url)) throw new UserError('this host is blocked (VIVCTL_DENY)');
      await inUI('navigate', {id, url}); await settle(id, 300);
      const t = (await listTabs()).find(x => x.id === id);
      return {title: t?.title, url: stripUrl(t?.url || '')};
    },
    focus: async p => (await inUI('focus', {id: tabArg(p)}), await settle(tabArg(p)), {}),
    back: async p => (await inUI('history', {id: tabArg(p), how: 'goBack'}), await settle(tabArg(p), 300), {}),
    forward: async p => (await inUI('history', {id: tabArg(p), how: 'goForward'}), await settle(tabArg(p), 300), {}),
    reload: async p => (await inUI('history', {id: tabArg(p), how: 'reload'}), await settle(tabArg(p), 300), {}),
    // A real mouse click on the element's center, but only if the element is what is under that
    // point: a cookie banner or a modal on top is reported instead of clicked. If the browser does
    // not deliver the click (tab not in front), the element is clicked from the page.
    click: p => onPage(tabArg(p), async ({send, run, tab}) => {
      const ref = asInt(p.ref, 'ref');
      const before = new Set((await listTabs()).map(t => t.id));
      const f = await run(PAGE.aim, {ref});
      if (f.error) throw new UserError('that element is gone, run `vivctl elements` again');
      if (!f.ok && !p.force) throw new UserError(`"${f.label}" is covered by "${f.cover}"; deal with that first, or use --force`);
      let via = 'script';
      if (f.ok) {
        for (const [type, extra] of [['mouseMoved', {}], ['mousePressed', {button: 'left', clickCount: 1}], ['mouseReleased', {button: 'left', clickCount: 1}]]) {
          await send('Input.dispatchMouseEvent', {type, x: f.x, y: f.y, ...extra});
        }
        if (await run(PAGE.clicked)) via = 'mouse';
      }
      if (via === 'script' && !await run(PAGE.jsclick, {ref})) throw new UserError('that element is gone, run `vivctl elements` again');
      await settle(tab.id, 300);
      const after = await listTabs();
      const self = after.find(t => t.id === tab.id);
      const opened = after.filter(t => !before.has(t.id)).map(t => t.id);
      return {clicked: f.label, via, ...(opened.length && {newTabs: opened}),
        ...(self && self.url !== tab.url && {navigated: stripUrl(self.url)})};
    }),
    type: p => onPage(tabArg(p), async ({send, run, tab}) => {
      const ref = asInt(p.ref, 'ref');
      if (typeof p.text !== 'string' || p.text.length > 5000) throw new UserError('text must be a string of at most 5000 characters');
      const f = await run(PAGE.focus, {ref});
      if (f.error === 'password') throw new UserError('refusing to type into a password field: secrets must not pass through the model, type it yourself');
      if (f.error === 'not editable') throw new UserError('that element does not take text (for a select use `vivctl select`)');
      if (f.error === 'read-only') throw new UserError('that element is read-only or disabled');
      if (f.error) throw new UserError('that element is gone, run `vivctl elements` again');
      // Real text input first. Vivaldi drops it for a tab that is not in front, and then the value
      // is set from the page. Either way the result is checked.
      await send('Input.insertText', {text: p.text});
      let via = 'keyboard';
      if (!await run(PAGE.typed, {ref, text: p.text})) {
        via = 'script';
        await run(PAGE.setvalue, {ref, text: p.text});
        if (!await run(PAGE.typed, {ref, text: p.text})) throw new UserError('the text did not arrive in the element (the page may block scripted input)');
      }
      const enter = p.enter ? await pressKey(send, run, 'Enter') : null;
      await settle(tab.id, p.enter ? 300 : 100);
      return {typed: p.text.length, via, ...(enter && {enter: enter.via, ...(enter.submitted && {submitted: true})})};
    }),
    press: p => onPage(tabArg(p), async ({send, run, tab}) => {
      if (!Object.hasOwn(KEYS, p.key)) throw new UserError(`unknown key "${p.key}", use one of: ${Object.keys(KEYS).join(', ')}`);
      const r = await pressKey(send, run, p.key);
      await settle(tab.id);
      return {key: p.key, ...r};
    }),
    select: p => onPage(tabArg(p), async ({run, tab}) => {
      const ref = asInt(p.ref, 'ref');
      if (typeof p.value !== 'string' || !p.value) throw new UserError('give the option to select, by its text or value');
      const r = await run(PAGE.select, {ref, value: p.value});
      if (r.error === 'not a select') throw new UserError('that element is not a select; for a custom dropdown use click');
      if (r.error === 'no option') throw new UserError(`no option matches "${p.value}"; options: ${r.options.join(' | ')}`);
      if (r.error) throw new UserError('that element is gone, run `vivctl elements` again');
      await settle(tab.id, 100);
      return r;
    }),
    scroll: p => onPage(tabArg(p), async ({run, tab}) => {
      if (!['up', 'down', 'top', 'bottom'].includes(p.to)) throw new UserError('scroll up, down, top or bottom');
      const r = await run(PAGE.scroll, {to: p.to});
      await settle(tab.id, 100);
      return r;
    }),
    screenshot: p => onPage(tabArg(p), async ({sessionId}) => {
      const r = await cdp('Page.captureScreenshot', {format: 'png'}, sessionId, 6000).catch(() => {
        throw new UserError(`could not capture the tab: a tab in the background has no picture, run \`vivctl focus ${tabArg(p)}\` first`);
      });
      const dir = path.join(STATE, 'shots');
      fs.mkdirSync(dir, {recursive: true, mode: 0o700});
      const old = fs.readdirSync(dir).sort();
      for (const f of old.slice(0, Math.max(0, old.length - 19))) fs.rmSync(path.join(dir, f), {force: true});
      const file = path.join(dir, `${Date.now()}-${tabArg(p)}.png`);
      fs.writeFileSync(file, Buffer.from(r.data, 'base64'), {mode: 0o600});
      return {file};
    }),
    windows: async () => {
      const [wins, tabs] = await Promise.all([inUI('windows', {}, {bg: true}), listTabs()]);
      return wins.filter(w => w.type === 'normal').map(w => {
        const own = tabs.filter(t => t.windowId === w.id);
        return {id: w.id, focused: w.focused, state: w.state, tabs: own.length, stacks: stacksOf(own).length,
          active: own.find(t => t.active)?.id};
      });
    },
    // One source (tab ids, a stack, or a whole window) to one target (a window id, or "new").
    move: async p => {
      const sources = [p.tabs?.length ? 'tabs' : null, p.stack ? 'stack' : null, p.window !== undefined ? 'window' : null].filter(Boolean);
      if (sources.length !== 1) throw new UserError('move takes tab ids, --stack STACK or --window WINDOW, exactly one of them');
      if (p.to === undefined) throw new UserError('say where to: --to WINDOW or --to new');
      const to = p.to === 'new' ? 'new' : asInt(p.to, 'window');
      const tabs = await listTabs();
      let ids;
      if (p.stack) ids = (await resolveStack(p.stack)).tabs;
      else if (p.window !== undefined) {
        const from = asInt(p.window, 'window');
        ids = tabs.filter(t => t.windowId === from).map(t => t.id);
        if (!ids.length) throw new UserError(`no window ${from}, see \`vivctl windows\``);
        if (from === to) throw new UserError('that is the same window');
      } else ids = [...new Set(p.tabs.map(t => asInt(t, 'tab')))];
      for (const id of ids) if (!tabs.some(t => t.id === id)) throw new UserError(`no such tab: ${id}`);
      if (to !== 'new' && !tabs.some(t => t.windowId === to)) throw new UserError(`no window ${to}, see \`vivctl windows\``);
      // A stack moves whole or not at all: tabs taken from a stack whose other tabs stay behind
      // leave it first, so that no stack ends up split across two windows.
      const touched = stacksOf(tabs).filter(s => s.tabs.some(id => ids.includes(id)));
      const whole = touched.filter(s => s.tabs.every(id => ids.includes(id)));
      const leaving = touched.filter(s => !whole.includes(s)).flatMap(s => s.tabs.filter(id => ids.includes(id)));
      if (leaving.length) await inUI('ungroup', {ids: leaving}, {bg: true});
      const windowId = await inUI('move', {ids, to, focus: !!p.focus}, {bg: true});
      // Vivaldi drops the stack of a tab that changes windows. A stack that moved whole is put back
      // together in the new window, with its title and color; only its id is new.
      const after = await listTabs();
      const restacked = [];
      for (const s of whole) {
        const groups = new Set(s.tabs.map(id => after.find(t => t.id === id)?.group));
        const [g] = groups;
        if (groups.size === 1 && g && after.filter(t => t.group === g).length === s.tabs.length) continue;
        const grouped = s.tabs.filter(id => after.find(t => t.id === id)?.group);
        if (grouped.length) await inUI('ungroup', {ids: grouped});
        restacked.push(await inUI('stack', {first: s.tabs[0], others: s.tabs.slice(1), expect: s.tabs,
          ...(s.title && {title: s.title}), ...(s.color && {color: asColor(s.color)})}));
      }
      return {moved: ids, window: windowId, ...(restacked.length && {stacks: restacked}), ...(leaving.length && {leftStack: leaving})};
    },
    quit: async () => { await cdp('Browser.close'); return {}; },
  };
}
