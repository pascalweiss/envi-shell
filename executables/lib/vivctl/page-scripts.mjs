// Code that runs inside a web page. Same rule as above: fixed strings, input only as `P`. It runs
// in an isolated world (like Playwright's utility world): it shares the DOM with the page but not
// its JavaScript, so a page cannot break or observe these helpers by patching globals.
//
// PAGE_LIB is prepended to every page script. vRoots lists the document, every open shadow root
// and every same-origin iframe document, so elements there are found too. Cross-origin iframes
// and closed shadow roots stay out of reach.
export const PAGE_LIB = `
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
// What counts as clickable. vSEL is what announces itself (tags, roles, onclick). Many pages build
// controls from plain elements with a script handler instead, which only their pointer cursor
// gives away, so the outermost element of a pointer area counts too, as do labels, a few more
// roles and tabindex. A checkbox or radio styled away (vTiny) leaves the click to its label or tile.
const vSEL='a[href],button,input,select,textarea,summary,[role=button],[role=link],[role=checkbox],[role=tab],[role=menuitem],[role=option],[onclick],[contenteditable=""],[contenteditable=true]';
const vROLES=["radio","switch","combobox","row","gridcell","treeitem","menuitemcheckbox","menuitemradio"];
const vStyle=el=>el.ownerDocument.defaultView.getComputedStyle(el);
const vShown=el=>{const b=el.getBoundingClientRect(),cs=vStyle(el);
  return !(b.width<1||b.height<1||cs.visibility==="hidden"||cs.display==="none"||el.type==="hidden")};
const vTiny=el=>{if(el.tagName!=="INPUT"||(el.type!=="checkbox"&&el.type!=="radio")) return false;
  const b=el.getBoundingClientRect(); return b.width<4||b.height<4||Number(vStyle(el).opacity)===0};
const vParentEl=el=>el.parentElement||(el.parentNode&&el.parentNode.host)||null;
const vPointer=el=>vStyle(el).cursor==="pointer";
const vTop=el=>el.tagName==="HTML"||el.tagName==="BODY";
const vMarked=el=>el.tagName==="LABEL"||vROLES.includes(el.getAttribute("role"));
// The element a click on el should go to: the nearest announced control or marked element above
// it, else the outermost element of the pointer area it sits in. Tabindex alone does not count
// here: a focusable container is no reason to click its center instead of the text.
const vClickable=el=>{let n=el,ptr=null;
  for(let i=0;n&&n.nodeType===1&&i<80&&!vTop(n);i++){
    if(n.matches(vSEL)&&!vTiny(n)||vMarked(n)) return n;
    if(vPointer(n)) ptr=n; else if(ptr) return ptr;
    n=vParentEl(n)}
  return ptr};
`;

export const PAGE = {
  read: `(()=>{const parts=[document.body?document.body.innerText:""];
    for(const r of vRoots().slice(1)){
      if(r.nodeType===11){
        const t=[...r.children].filter(c=>!["STYLE","SCRIPT","TEMPLATE","LINK"].includes(c.tagName)&&(!c.checkVisibility||c.checkVisibility()))
          .map(c=>c.innerText||"").join("\\n").trim();
        if(t) parts.push("[in "+r.host.tagName.toLowerCase()+"]\\n"+t);
      } else if(r.body){const t=r.body.innerText.trim(); if(t) parts.push("[frame]\\n"+t)}
    }
    return {title:document.title,url:location.href,text:parts.join("\\n\\n")}})()`,
  // Announced controls first, then the rest (see vSEL above): an element that wraps a listed
  // control or another candidate gives way to it, so a tile and its label, or a label and its
  // checkbox, never both get a ref. Numbered in document order.
  elements: `(()=>{const roots=vRoots();
    for(const r of roots) r.querySelectorAll("[data-vivctl-ref]").forEach(e=>e.removeAttribute("data-vivctl-ref"));
    const out=[]; let n=0;
    for(const r of roots){
      const std=[...r.querySelectorAll(vSEL)].filter(el=>vShown(el)&&!vTiny(el)), stdSet=new Set(std);
      const cand=[];
      for(const el of r.querySelectorAll("*")){
        if(stdSet.has(el)||vTop(el)) continue;
        const p=vParentEl(el);
        const focusable=el.hasAttribute("tabindex")&&el.tabIndex>=0;
        if(!(vMarked(el)||focusable||(vPointer(el)&&!(p&&p.nodeType===1&&vPointer(p))))) continue;
        if(!vShown(el)) continue;
        const inCtl=p&&p.closest?p.closest(vSEL):null;
        if(inCtl&&stdSet.has(inCtl)) continue;
        cand.push(el);
      }
      const extra=cand.filter(el=>!std.some(s=>s!==el&&el.contains(s))&&!cand.some(c=>c!==el&&el.contains(c)));
      const all=[...std,...extra].sort((a,b)=>a===b?0:(a.compareDocumentPosition(b)&4?-1:1));
      for(const el of all){
        n++; el.setAttribute("data-vivctl-ref",String(n));
        const sel1=el.tagName==="SELECT"&&el.selectedOptions&&el.selectedOptions[0];
        const lab1=el.labels&&el.labels.length?el.labels[0].innerText:"";
        const label=vText(el.getAttribute("aria-label")||(sel1?sel1.text:"")||el.innerText||lab1||el.placeholder||el.title||el.getAttribute("alt")||(el.type==="password"?"":el.value)||el.name||"").slice(0,80);
        const o={ref:n,tag:el.tagName.toLowerCase(),type:el.type||el.getAttribute("role")||undefined,label,href:el.href||undefined};
        const ctl=el.tagName==="LABEL"?el.control:null, aria=el.getAttribute("aria-checked");
        if(el.type==="checkbox"||el.type==="radio") o.checked=el.checked;
        else if(ctl&&(ctl.type==="checkbox"||ctl.type==="radio")) o.checked=ctl.checked;
        else if(aria==="true"||aria==="false") o.checked=aria==="true";
        if(el.disabled) o.disabled=true;
        if(el.tagName==="SELECT") o.options=[...el.options].slice(0,30).map(x=>vText(x.text));
        if(r!==document) o.in=r.nodeType===11?"shadow":"frame";
        out.push(o);
        if(n>=400) return out;
      }
    }
    return out})()`,
  // The one element a click by text goes to. Of the visible elements whose text (or aria-label,
  // or button value) contains the text, the innermost win, exact matches before partial ones;
  // each is then lifted to vClickable. More than one target is an error, never a guess.
  findtext: `(()=>{const want=vText(P.text).toLowerCase(); if(!want) return {error:"empty"};
    for(const r of vRoots()) r.querySelectorAll('[data-vivctl-ref="text"]').forEach(e=>e.removeAttribute("data-vivctl-ref"));
    const skip=["SCRIPT","STYLE","NOSCRIPT","TEMPLATE","HEAD","TITLE","HTML","BODY"];
    const hits=[];
    for(const r of vRoots()){ for(const el of r.querySelectorAll("*")){
      if(skip.includes(el.tagName)) continue;
      const al=vText(el.getAttribute("aria-label")).toLowerCase();
      const bv=el.tagName==="INPUT"&&["submit","button","reset"].includes(el.type)?vText(el.value).toLowerCase():"";
      if(!vText(el.textContent).toLowerCase().includes(want)&&!al.includes(want)&&!bv.includes(want)) continue;
      if(!vShown(el)) continue;
      const t=vText(el.innerText).toLowerCase();
      if(!t.includes(want)&&!al.includes(want)&&!bv.includes(want)) continue;
      hits.push({el,exact:t===want||al===want||bv===want});
    }}
    let inner=hits.filter(h=>!hits.some(o=>o.el!==h.el&&h.el.contains(o.el)));
    if(inner.some(h=>h.exact)) inner=inner.filter(h=>h.exact);
    const targets=[];
    for(const h of inner){const t=vClickable(h.el)||h.el; if(!targets.includes(t)) targets.push(t)}
    if(!targets.length) return {error:"none"};
    if(targets.length>1) return {error:"ambiguous",candidates:targets.slice(0,10).map(vDesc)};
    targets[0].setAttribute("data-vivctl-ref","text"); return {ref:"text"}})()`,
  // A click at viewport coordinates (CSS pixels, the pixels of a screenshot): what is there, and a
  // listener in that element's window that tells afterwards whether the click arrived.
  atpoint: `(()=>{if(!(P.x>=0&&P.y>=0&&P.x<innerWidth&&P.y<innerHeight)) return {error:"outside",w:innerWidth,h:innerHeight};
    const hit=vAt(P.x,P.y); if(!hit) return {error:"nothing"};
    vArm(hit.ownerDocument.defaultView,["pointerdown","mousedown","click"],"__vivctlClick");
    return {label:vDesc(hit)}})()`,
  jsclickat: `(()=>{const el=vAt(P.x,P.y); if(!el) return false;
    if(typeof el.click==="function") el.click(); else el.dispatchEvent(new MouseEvent("click",{bubbles:true,cancelable:true,composed:true}));
    return true})()`,
  // The visible part of the page in CSS pixels, so that a screenshot maps 1:1 to click --at.
  viewport: `(()=>{const v=window.visualViewport;
    return {x:v?v.pageLeft:scrollX,y:v?v.pageTop:scrollY,w:v?v.width:innerWidth,h:v?v.height:innerHeight,dpr:devicePixelRatio||1}})()`,
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
