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

import {spawn, spawnSync} from 'node:child_process';
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
const SOURCE_PROFILE = process.env.VIVCTL_SOURCE_PROFILE || path.join(HOME, 'Library/Application Support/Vivaldi');
const BROWSER = process.env.VIVALDI_BIN || '/Applications/Vivaldi.app/Contents/MacOS/Vivaldi';

const COLORS = {grey: 'color1', blue: 'color2', red: 'color3', yellow: 'color4', green: 'color5',
  pink: 'color6', purple: 'color7', teal: 'color8', orange: 'color9'};
const COLOR_NAME = Object.fromEntries(Object.entries(COLORS).map(([k, v]) => [v, k]));
// Access control: the daemon starts locked and a Touch ID check opens it for a lease.
const AUTH_OFF = process.env.VIVCTL_AUTH === 'off';
const AUTH_BIN = process.env.VIVCTL_AUTH_BIN || '';
const LEASE_MS = (Number(process.env.VIVCTL_LEASE_MINUTES) || 60) * 60000;
// Hosts whose pages the page operations refuse (comma separated suffixes). Empty by default.
const DENY = (process.env.VIVCTL_DENY || '').split(',').map(x => x.trim().toLowerCase()).filter(Boolean);
const OPEN_OPS = new Set(['ping', 'unlock', 'lock']); // the only operations that work while locked

class UserError extends Error {}

const hostDenied = u => {
  try { const h = new URL(u).hostname.toLowerCase(); return DENY.some(d => h === d || h.endsWith('.' + d)); } catch { return false; }
};
const KEYS = {Enter: 13, Tab: 9, Escape: 27, Backspace: 8, Space: 32, ArrowLeft: 37, ArrowUp: 38, ArrowRight: 39,
  ArrowDown: 40, PageUp: 33, PageDown: 34, Home: 36, End: 35};

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
      status:t.status,title:t.title||"",url:t.url||t.pendingUrl||"",group:e.group,groupTitle:e.fixedGroupTitle,groupColor:e.groupColor}})`,
  open: `
    const t=await new Promise(r=>chrome.tabs.create({url:P.url,active:P.focus,windowId:P.windowId},r));
    await wait(300); return t.id`,
  // Joins P.others to the stack of P.first, creating it if P.first has none. Before a title or
  // color is set, the stack must hold exactly P.expect: a stack with other tabs in it belongs to
  // somebody else and is never renamed. Errors marked [user] reach the caller as plain messages.
  stack: `
    let all=await q(); const first=all.find(t=>t.id===P.first);
    if(!first) throw new Error("[user] no such tab: "+P.first);
    let group=ext(first).group;
    for(const id of P.others){
      if(!all.find(t=>t.id===id)) throw new Error("[user] no such tab: "+id);
      const r=await vivaldi.tabsPrivate.move({tabIds:[id],target:ext(first).ext_id,windowId:first.windowId,
        tweaks:group?TW:[...TW,"create-group"],debug:"vivctl"});
      if(!r.success) throw new Error("Vivaldi refused to move tab "+id);
      await wait(300);
      all=await q(); group=ext(all.find(t=>t.id===P.first)).group||r.group||group;
    }
    if(!group) throw new Error("[user] tab "+P.first+" is not in a stack");
    const num=(a,b)=>a-b, got=(await q()).filter(t=>ext(t).group===group).map(t=>t.id).sort(num), want=[...P.expect].sort(num);
    if(got.join()!==want.join()) throw new Error("[user] the stack came out with tabs "+got.join(" ")+" instead of "+want.join(" ")+"; nothing was renamed");
    if(P.title!==undefined||P.color!==undefined){
      const pr={groupExtId:group}; if(P.title!==undefined) pr.groupTitle=P.title; if(P.color!==undefined) pr.groupColor=P.color;
      await vivaldi.tabsPrivate.setGroupProperties(pr);
    }
    return group`,
  props: `
    const pr={groupExtId:P.group}; if(P.title!==undefined) pr.groupTitle=P.title; if(P.color!==undefined) pr.groupColor=P.color;
    await vivaldi.tabsPrivate.setGroupProperties(pr); return true`,
  unstack: `await vivaldi.tabsPrivate.unstack(P.group); return true`,
  // Takes tabs out of whatever stack they are in, the way Vivaldi's own "Remove from stack" does:
  // a move to the end of the window with the "ungroup" tweak. Only these tabs move; their old
  // stack keeps its other tabs, its id, title and color. Returns the ids that had to leave a stack.
  ungroup: `
    const all=await q(); const hit=all.filter(t=>P.ids.includes(t.id)&&ext(t).group);
    for(const w of [...new Set(hit.map(t=>t.windowId))]){
      const end=Math.max(...all.filter(t=>t.windowId===w).map(t=>t.index))+1;
      const r=await vivaldi.tabsPrivate.move({tabIds:hit.filter(t=>t.windowId===w).map(t=>t.id),target:end,windowId:w,
        tweaks:["untile","ungroup"],debug:"vivctl"});
      if(r&&r.success===false) throw new Error("Vivaldi refused to take tabs out of their stack");
    }
    if(hit.length) await wait(300);
    const left=(await q()).filter(t=>P.ids.includes(t.id)&&ext(t).group).map(t=>t.id);
    if(left.length) throw new Error("tabs still in a stack after ungroup: "+left.join(" "));
    return hit.map(t=>t.id)`,
  close: `await new Promise(r=>chrome.tabs.remove(P.ids,r)); return P.ids`,
  status: `const t=await new Promise(r=>chrome.tabs.get(P.id,r)); return t?{status:t.status,title:t.title||"",discarded:!!t.discarded}:null`,
  navigate: `await new Promise(r=>chrome.tabs.update(P.id,{url:P.url},r)); return true`,
  focus: `await new Promise(r=>chrome.tabs.update(P.id,{active:true},r)); return true`,
  history: `await new Promise(r=>chrome.tabs[P.how](P.id,r)); return true`,
};

// Code that runs inside a web page. Same rule as above: fixed strings, input only as `P`. It runs
// in an isolated world (like Playwright's utility world): it shares the DOM with the page but not
// its JavaScript, so a page cannot break or observe these helpers by patching globals.
//
// PAGE_LIB is prepended to every page script. vRoots lists the document, every open shadow root
// and every same-origin iframe document, so elements there are found too. Cross-origin iframes
// and closed shadow roots stay out of reach.
const PAGE_LIB = `
const vRoots=()=>{const out=[];const add=root=>{out.push(root);
  for(const el of root.querySelectorAll("*")){
    if(el.shadowRoot) add(el.shadowRoot);
    if(el.tagName==="IFRAME"||el.tagName==="FRAME"){let d=null;try{d=el.contentDocument}catch(e){} if(d&&d.documentElement) add(d);}
  }};add(document);return out};
const vFind=ref=>{for(const r of vRoots()){const el=r.querySelector('[data-vivctl-ref="'+ref+'"]'); if(el) return el;} return null};
const vOffset=el=>{let x=0,y=0,w=el.ownerDocument.defaultView;
  while(w&&w.frameElement){const f=w.frameElement,b=f.getBoundingClientRect();x+=b.left+f.clientLeft;y+=b.top+f.clientTop;w=f.ownerDocument.defaultView}
  return {x,y}};
const vAt=(x,y)=>{let el=document.elementFromPoint(x,y),ox=0,oy=0;
  for(let i=0;el&&i<30;i++){
    if(el.shadowRoot){const n=el.shadowRoot.elementFromPoint(x-ox,y-oy); if(n&&n!==el){el=n;continue}}
    if(el.tagName==="IFRAME"||el.tagName==="FRAME"){let c=null;try{c=el.contentDocument}catch(e){}
      if(c){const b=el.getBoundingClientRect();ox+=b.left+el.clientLeft;oy+=b.top+el.clientTop;const n=c.elementFromPoint(x-ox,y-oy);if(n){el=n;continue}}}
    break}
  return el};
const vUp=n=>n.parentNode||(n.nodeType===11&&n.host)||(n.nodeType===9&&n.defaultView&&n.defaultView.frameElement)||null;
const vWithin=(el,n)=>{for(let i=0;n&&i<2000;i++){if(n===el)return true;n=vUp(n)}return false};
const vActive=()=>{let a=document.activeElement;
  for(let i=0;a&&i<30;i++){
    if(a.shadowRoot&&a.shadowRoot.activeElement){a=a.shadowRoot.activeElement;continue}
    if(a.tagName==="IFRAME"||a.tagName==="FRAME"){let d=null;try{d=a.contentDocument}catch(e){} if(d&&d.activeElement){a=d.activeElement;continue}}
    break}
  return a};
const vText=s=>(s||"").replace(/\\s+/g," ").trim();
const vDesc=el=>el?(el.tagName.toLowerCase()+" "+vText(el.getAttribute("aria-label")||el.innerText||el.value||"").slice(0,50)).trim():"nothing";
const vArm=(w,types,flag)=>{window[flag]=false;for(const t of types) w.addEventListener(t,()=>{window[flag]=true},{capture:true,once:true})};
`;

const PAGE = {
  read: `(()=>{const parts=[document.body?document.body.innerText:""];
    for(const r of vRoots().slice(1)){
      if(r.nodeType===11){
        const t=[...r.children].filter(c=>!["STYLE","SCRIPT","TEMPLATE","LINK"].includes(c.tagName)&&(!c.checkVisibility||c.checkVisibility()))
          .map(c=>c.innerText||"").join("\\n").trim();
        if(t) parts.push("[in "+r.host.tagName.toLowerCase()+"]\\n"+t);
      } else if(r.body){const t=r.body.innerText.trim(); if(t) parts.push("[frame]\\n"+t)}
    }
    return {title:document.title,url:location.href,text:parts.join("\\n\\n")}})()`,
  elements: `(()=>{const roots=vRoots();
    for(const r of roots) r.querySelectorAll("[data-vivctl-ref]").forEach(e=>e.removeAttribute("data-vivctl-ref"));
    const sel='a[href],button,input,select,textarea,summary,[role=button],[role=link],[role=checkbox],[role=tab],[role=menuitem],[role=option],[onclick],[contenteditable=""],[contenteditable=true]';
    const out=[]; let n=0;
    for(const r of roots){ for(const el of r.querySelectorAll(sel)){
      const b=el.getBoundingClientRect(), cs=el.ownerDocument.defaultView.getComputedStyle(el);
      if(b.width<1||b.height<1||cs.visibility==="hidden"||cs.display==="none"||el.type==="hidden") continue;
      n++; el.setAttribute("data-vivctl-ref",String(n));
      const sel1=el.tagName==="SELECT"&&el.selectedOptions&&el.selectedOptions[0];
      const lab1=el.labels&&el.labels.length?el.labels[0].innerText:"";
      const label=vText(el.getAttribute("aria-label")||(sel1?sel1.text:"")||el.innerText||lab1||el.placeholder||el.title||el.getAttribute("alt")||(el.type==="password"?"":el.value)||el.name||"").slice(0,80);
      const o={ref:n,tag:el.tagName.toLowerCase(),type:el.type||undefined,label,href:el.href||undefined};
      if(el.type==="checkbox"||el.type==="radio") o.checked=el.checked;
      if(el.disabled) o.disabled=true;
      if(el.tagName==="SELECT") o.options=[...el.options].slice(0,30).map(x=>vText(x.text));
      if(r!==document) o.in=r.nodeType===11?"shadow":"frame";
      out.push(o);
      if(n>=400) return out;
    }}
    return out})()`,
  // Scroll the element into view, check that nothing covers it, and arm a listener that tells
  // afterwards whether the browser actually delivered the click.
  aim: `(()=>{const el=vFind(P.ref); if(!el) return {error:"stale"};
    el.scrollIntoView({block:"center",inline:"center"});
    const b=el.getBoundingClientRect(), o=vOffset(el);
    const x=o.x+b.left+b.width/2, y=o.y+b.top+b.height/2;
    const hit=vAt(x,y), lab=hit&&hit.closest?hit.closest("label"):null;
    const ok=!!hit&&(vWithin(el,hit)||(!!lab&&lab.control===el));
    vArm(el.ownerDocument.defaultView,["pointerdown","mousedown","click"],"__vivctlClick");
    return {x,y,ok,cover:ok?"":vDesc(hit),label:vDesc(el)}})()`,
  clicked: `window.__vivctlClick===true`,
  jsclick: `(()=>{const el=vFind(P.ref); if(!el) return false;
    if(typeof el.click==="function") el.click(); else el.dispatchEvent(new MouseEvent("click",{bubbles:true,cancelable:true,composed:true}));
    return true})()`,
  focus: `(()=>{const el=vFind(P.ref); if(!el) return {error:"stale"};
    if(el.type==="password") return {error:"password"};
    const noText=["checkbox","radio","button","submit","reset","file","image","range","color"];
    if(!(el.isContentEditable||el.tagName==="TEXTAREA"||(el.tagName==="INPUT"&&!noText.includes(el.type)))) return {error:"not editable"};
    if(el.readOnly||el.disabled) return {error:"read-only"};
    el.scrollIntoView({block:"center"}); el.focus();
    try{ if(el.isContentEditable) el.ownerDocument.getSelection().selectAllChildren(el); else if(typeof el.select==="function") el.select(); }catch(e){}
    return {ok:true}})()`,
  typed: `(()=>{const el=vFind(P.ref); if(!el) return false;
    const v=el.isContentEditable?el.innerText:el.value; return typeof v==="string"&&v.includes(P.text)})()`,
  // Seen from the isolated world, el.value is the native setter: a framework's own tracking on
  // the element (React) does not see the change, so the input event registers as a real edit.
  setvalue: `(()=>{const el=vFind(P.ref); if(!el||el.type==="password") return false;
    if(el.isContentEditable){const d=el.ownerDocument; el.focus(); d.getSelection().selectAllChildren(el); return d.execCommand("insertText",false,P.text)}
    el.value=P.text;
    el.dispatchEvent(new Event("input",{bubbles:true,composed:true})); el.dispatchEvent(new Event("change",{bubbles:true}));
    return true})()`,
  keyarm: `(()=>{const a=vActive(); vArm((a?a.ownerDocument:document).defaultView,["keydown","keyup"],"__vivctlKey"); return true})()`,
  keyed: `window.__vivctlKey===true`,
  // Fallback when the browser did not deliver a key: the page's handlers see the events (not as
  // trusted), and Enter in a form submits it, which is what the browser would have done.
  jskey: `(()=>{const a=vActive()||document.body;
    const init={key:P.key,code:P.code,keyCode:P.keyCode,which:P.keyCode,bubbles:true,cancelable:true,composed:true};
    const go=a.dispatchEvent(new KeyboardEvent("keydown",init));
    if(go&&P.key==="Enter") a.dispatchEvent(new KeyboardEvent("keypress",Object.assign({},init,{charCode:13})));
    a.dispatchEvent(new KeyboardEvent("keyup",init));
    let submitted=false;
    if(go&&P.key==="Enter"&&a.form&&a.tagName!=="TEXTAREA"){ if(a.form.requestSubmit) a.form.requestSubmit(); else a.form.submit(); submitted=true }
    return {submitted}})()`,
  select: `(()=>{const el=vFind(P.ref); if(!el) return {error:"stale"}; if(el.tagName!=="SELECT") return {error:"not a select"};
    const want=P.value.toLowerCase(), opts=[...el.options];
    const o=opts.find(x=>x.value===P.value)||opts.find(x=>vText(x.text).toLowerCase()===want)||opts.find(x=>vText(x.text).toLowerCase().includes(want));
    if(!o) return {error:"no option",options:opts.slice(0,30).map(x=>vText(x.text))};
    el.value=o.value;
    el.dispatchEvent(new Event("input",{bubbles:true,composed:true})); el.dispatchEvent(new Event("change",{bubbles:true}));
    return {selected:vText(o.text)}})()`,
  scroll: `(()=>{const h=innerHeight*0.85, s=document.scrollingElement||document.documentElement;
    if(P.to==="top") scrollTo(0,0); else if(P.to==="bottom") scrollTo(0,s.scrollHeight); else scrollBy(0,P.to==="up"?-h:h);
    return {y:Math.round(scrollY),max:Math.max(0,Math.round(s.scrollHeight-innerHeight))}})()`,
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
  const cdp = (method, params = {}, sessionId, timeoutMs = 15000) => new Promise((resolve, reject) => {
    const id = ++seq;
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`${method} timed out`)); }, timeoutMs);
    pending.set(id, {resolve: v => { clearTimeout(timer); resolve(v); }, reject: e => { clearTimeout(timer); reject(e); }});
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
    if (r.exceptionDetails) {
      const msg = r.exceptionDetails.exception?.description?.split('\n')[0] || 'UI call failed';
      const user = msg.match(/\[user\] (.*)$/);
      throw user ? new UserError(user[1]) : new Error(msg);
    }
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

  // ------------------------------------------------------------- page access
  const sleep = ms => new Promise(r => setTimeout(r, ms));
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
  const tabArg = p => asInt(p.tab, 'tab');
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
    title: async p => (await inUI('props', {group: (await resolveStack(p.stack)).id, title: asTitle(p.title)}), {}),
    color: async p => (await inUI('props', {group: (await resolveStack(p.stack)).id, color: asColor(p.color)}), {}),
    unstack: async p => (await inUI('unstack', {group: (await resolveStack(p.stack)).id}), {}),
    'close-stack': async p => ({closed: await inUI('close', {ids: (await resolveStack(p.stack)).tabs})}),
    close: async p => ({closed: await inUI('close', {ids: (p.tabs || []).map(t => asInt(t, 'tab'))})}),
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
  const valued = new Set(['title', 'color', 'into', 'stack', 'max']), flags = new Set(['json', 'focus', 'enter', 'force']);
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

  vivctl init                         once per Mac: copy Vivaldi's profile for the daemon to run
  vivctl start | stop | status        run Vivaldi under the control daemon
  vivctl unlock | lock                Touch ID opens every other command for a while (default 60 min)
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
