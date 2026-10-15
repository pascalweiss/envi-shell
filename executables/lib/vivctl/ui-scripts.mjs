// Code that runs inside Vivaldi's UI page. Every operation body is a fixed
// string; caller input only ever arrives as JSON in `P`, never as code.
export const PRE = `
const q=()=>new Promise(r=>chrome.tabs.query({},r));
const ext=t=>{try{return JSON.parse(t.vivExtData||"{}")}catch{return {}}};
const wait=ms=>new Promise(r=>setTimeout(r,ms));
const TW=["target-is-tab","do-not-reparent","on"];
`;

export const UI = {
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
  windows: `return (await new Promise(r=>chrome.windows.getAll({},r))).map(w=>({id:w.id,focused:w.focused,state:w.state,type:w.type}))`,
  // Moves tabs to the end of window P.to, or into a new window, the way Vivaldi's own "Move to
  // window" does (tabsPrivate.move with target -1). Tabs keep their stack. Runs on the background
  // page, since a window whose last tab leaves closes, UI page included.
  move: `
    let w=P.to;
    if(w==="new"){const nw=await new Promise(r=>chrome.windows.create({tabId:P.ids[0],focused:!!P.focus},r)); w=nw.id;}
    const rest=P.to==="new"?P.ids.slice(1):P.ids;
    if(rest.length){
      const r=await vivaldi.tabsPrivate.move({tabIds:rest,target:-1,windowId:w,tweaks:["do-not-reparent"],workspaceId:0,debug:"vivctl"});
      if(r&&r.success===false) throw new Error("Vivaldi refused to move the tabs");
    }
    await wait(400);
    const left=(await q()).filter(t=>P.ids.includes(t.id)&&t.windowId!==w).map(t=>t.id);
    if(left.length) throw new Error("tabs did not arrive in the window: "+left.join(" "));
    if(P.focus&&P.to!=="new") await new Promise(r=>chrome.windows.update(w,{focused:true},r));
    return w`,
  newWindow: `await new Promise(r=>chrome.windows.create({focused:true},()=>r(true))); return true`,
  status: `const t=await new Promise(r=>chrome.tabs.get(P.id,r)); return t?{status:t.status,title:t.title||"",discarded:!!t.discarded}:null`,
  navigate: `await new Promise(r=>chrome.tabs.update(P.id,{url:P.url},r)); return true`,
  focus: `await new Promise(r=>chrome.tabs.update(P.id,{active:true},r)); return true`,
  history: `await new Promise(r=>chrome.tabs[P.how](P.id,r)); return true`,
};
