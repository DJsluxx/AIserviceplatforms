// ============================================
//  Profit Prophet — app logic
// ============================================

const $  = (s, r=document) => r.querySelector(s);
const $$ = (s, r=document) => Array.from(r.querySelectorAll(s));

// -------- State --------
const state = {
  queue: [],               // upcoming ideas
  current: null,
  saved: JSON.parse(localStorage.getItem("pp_saved") || "[]"),
  stats: JSON.parse(localStorage.getItem("pp_stats") || '{"swipes":0,"saves":0,"passes":0,"likes":0,"seenNiches":{},"seenModels":{}}'),
  settings: JSON.parse(localStorage.getItem("pp_settings") || '{"sound":true,"haptics":true}'),
};

function persist(){
  localStorage.setItem("pp_saved", JSON.stringify(state.saved));
  localStorage.setItem("pp_stats", JSON.stringify(state.stats));
  localStorage.setItem("pp_settings", JSON.stringify(state.settings));
}

// -------- Haptics / sound --------
function buzz(pattern=12){
  if (!state.settings.haptics) return;
  try { navigator.vibrate?.(pattern); } catch(_) {}
}

let audioCtx = null;
function beep(freq=660,dur=0.08,type="sine",vol=0.04){
  if (!state.settings.sound) return;
  try {
    audioCtx = audioCtx || new (window.AudioContext||window.webkitAudioContext)();
    const o = audioCtx.createOscillator();
    const g = audioCtx.createGain();
    o.type = type; o.frequency.value = freq;
    g.gain.setValueAtTime(0,audioCtx.currentTime);
    g.gain.linearRampToValueAtTime(vol,audioCtx.currentTime+0.01);
    g.gain.exponentialRampToValueAtTime(0.0001,audioCtx.currentTime+dur);
    o.connect(g).connect(audioCtx.destination);
    o.start(); o.stop(audioCtx.currentTime+dur);
  } catch(_) {}
}

// -------- Toasts --------
let toastTimer = null;
function toast(msg){
  const t = $("#toast");
  t.textContent = msg;
  t.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(()=>t.classList.remove("show"), 1700);
}

// -------- Formatting --------
const fmt$ = (n) => {
  if (n >= 1e9) return "$" + (n/1e9).toFixed(1) + "B";
  if (n >= 1e6) return "$" + (n/1e6).toFixed(1) + "M";
  if (n >= 1e3) return "$" + (n/1e3).toFixed(1) + "k";
  return "$" + Math.round(n);
};

// -------- Particles (lightweight canvas) --------
(function particles(){
  const c = $("#particles");
  const ctx = c.getContext("2d");
  let w,h,parts=[];
  function resize(){
    w = c.width = window.innerWidth*devicePixelRatio;
    h = c.height = window.innerHeight*devicePixelRatio;
    c.style.width = window.innerWidth+"px";
    c.style.height = window.innerHeight+"px";
  }
  resize();
  window.addEventListener("resize", resize);
  const colors = ["#ffd166","#a78bfa","#f472b6","#34d399","#60a5fa"];
  for (let i=0;i<26;i++){
    parts.push({
      x:Math.random()*w,y:Math.random()*h,
      r:(Math.random()*2+.5)*devicePixelRatio,
      dx:(Math.random()-.5)*.3,dy:(Math.random()-.5)*.3,
      c:colors[Math.floor(Math.random()*colors.length)],
      a:Math.random()*.4+.15,
    });
  }
  function tick(){
    ctx.clearRect(0,0,w,h);
    for (const p of parts){
      p.x += p.dx; p.y += p.dy;
      if (p.x<0||p.x>w) p.dx*=-1;
      if (p.y<0||p.y>h) p.dy*=-1;
      ctx.beginPath();
      ctx.arc(p.x,p.y,p.r*4,0,Math.PI*2);
      ctx.fillStyle = p.c + Math.round(p.a*40).toString(16).padStart(2,"0");
      ctx.filter = "blur(6px)";
      ctx.fill();
      ctx.filter = "none";
      ctx.beginPath();
      ctx.arc(p.x,p.y,p.r,0,Math.PI*2);
      ctx.fillStyle = p.c + "ff";
      ctx.globalAlpha = p.a;
      ctx.fill();
      ctx.globalAlpha = 1;
    }
    requestAnimationFrame(tick);
  }
  tick();
})();

// -------- Deck / swipe --------
const deck = $(".deck");

function prefill(n=4){
  while (state.queue.length < n) state.queue.push(generateIdea());
}

function renderDeck(){
  deck.innerHTML = "";
  // render up to 3 cards, topmost is interactive
  const visible = state.queue.slice(0,3);
  visible.forEach((idea,i)=>{
    const el = buildCard(idea, i);
    deck.appendChild(el);
  });
  if (visible[0]) {
    state.current = visible[0];
    attachDrag(deck.lastElementChild, visible[0]);
  }
}

function buildCard(idea, depth){
  const c = document.createElement("div");
  c.className = "card";
  c.style.zIndex = 10 - depth;
  c.style.transform = `translateY(${depth*8}px) scale(${1 - depth*0.04})`;
  c.style.opacity = depth === 0 ? 1 : (depth===1?.85:.6);
  c.style.pointerEvents = depth === 0 ? "auto" : "none";

  c.innerHTML = `
    <span class="tier ${idea.tier}">${idea.tierEmoji} ${idea.tier}</span>
    <div class="swipe-labels">
      <div class="swipe-label pass">PASS</div>
      <div class="swipe-label like">LIKE</div>
      <div class="swipe-label save">★ VAULT</div>
    </div>
    <div class="hero">
      <div class="emoji">${idea.emoji}</div>
      <div class="title">
        <h2>${escapeHtml(idea.name)}</h2>
        <p>${idea.model.emoji} ${escapeHtml(idea.model.name)} · ${escapeHtml(idea.niche.name)}</p>
      </div>
    </div>
    <div class="tagline">${escapeHtml(idea.tagline)}</div>
    <div class="stats">
      <div class="stat">
        <div class="k">Year 1 revenue</div>
        <div class="v">${fmt$(idea.year1Revenue)}<span class="sub">est.</span></div>
      </div>
      <div class="stat">
        <div class="k">Startup cost</div>
        <div class="v">${fmt$(idea.startupCost)}<span class="sub">init.</span></div>
      </div>
      <div class="stat">
        <div class="k">Market size</div>
        <div class="v">$${idea.marketSize}B<span class="sub">global</span></div>
      </div>
      <div class="stat">
        <div class="k">Growth</div>
        <div class="v">${idea.growthRate}%<span class="sub">YoY</span></div>
      </div>
    </div>
    <div class="bars">
      <div class="bar p"><div class="label"><span>Potential</span><span>${idea.potential}/10</span></div><div class="track"><div class="fill" style="width:${idea.potential*10}%"></div></div></div>
      <div class="bar u"><div class="label"><span>Uniqueness</span><span>${idea.uniqueness}/10</span></div><div class="track"><div class="fill" style="width:${idea.uniqueness*10}%"></div></div></div>
      <div class="bar s"><div class="label"><span>Speed</span><span>${idea.speed}/10</span></div><div class="track"><div class="fill" style="width:${idea.speed*10}%"></div></div></div>
      <div class="bar d"><div class="label"><span>Difficulty</span><span>${idea.difficulty}/10</span></div><div class="track"><div class="fill" style="width:${idea.difficulty*10}%"></div></div></div>
    </div>
  `;
  return c;
}

function escapeHtml(s){return String(s).replace(/[&<>"']/g, c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));}

function attachDrag(el, idea){
  let startX=0, startY=0, dx=0, dy=0, dragging=false;
  const passLbl = el.querySelector(".swipe-label.pass");
  const likeLbl = el.querySelector(".swipe-label.like");
  const saveLbl = el.querySelector(".swipe-label.save");
  const ac = new AbortController();
  const opts = { signal: ac.signal };

  function onDown(e){
    dragging = true;
    const p = e.touches ? e.touches[0] : e;
    startX = p.clientX; startY = p.clientY;
    el.style.transition = "none";
  }
  function onMove(e){
    if (!dragging) return;
    const p = e.touches ? e.touches[0] : e;
    dx = p.clientX - startX;
    dy = p.clientY - startY;
    const rot = dx * 0.06;
    el.style.transform = `translate(${dx}px,${dy}px) rotate(${rot}deg)`;
    const ax = Math.min(1, Math.abs(dx)/120);
    if (dx > 0) { likeLbl.style.opacity = ax; passLbl.style.opacity = 0; }
    else { passLbl.style.opacity = ax; likeLbl.style.opacity = 0; }
    saveLbl.style.opacity = (dy < -80) ? Math.min(1,(-dy-80)/80) : 0;
    if (e.cancelable) e.preventDefault();
  }
  function onUp(){
    if (!dragging) return;
    dragging = false;
    el.style.transition = "transform .42s var(--ease-spring), opacity .35s";
    const upSwipe = dy < -140 && Math.abs(dx) < 120;
    if (upSwipe)       { ac.abort(); fling(el, 0, -window.innerHeight, 0); return commit("save", idea); }
    if (dx > 120)      { ac.abort(); fling(el, window.innerWidth*1.2, dy, 30); return commit("like", idea); }
    if (dx < -120)     { ac.abort(); fling(el, -window.innerWidth*1.2, dy, -30); return commit("pass", idea); }
    el.style.transform = "";
    passLbl.style.opacity = 0; likeLbl.style.opacity = 0; saveLbl.style.opacity = 0;
    dx = 0; dy = 0;
  }
  function fling(node, x, y, rot){
    node.style.transform = `translate(${x}px,${y}px) rotate(${rot}deg)`;
    node.style.opacity = "0";
  }

  el.addEventListener("touchstart", onDown, { passive:true, signal: ac.signal });
  el.addEventListener("touchmove", onMove, { passive:false, signal: ac.signal });
  el.addEventListener("touchend", onUp, opts);
  el.addEventListener("touchcancel", onUp, opts);
  el.addEventListener("mousedown", onDown, opts);
  window.addEventListener("mousemove", onMove, opts);
  window.addEventListener("mouseup", onUp, opts);
}

function commit(action, idea){
  state.stats.swipes++;
  state.stats.seenNiches[idea.niche.name] = (state.stats.seenNiches[idea.niche.name]||0) + 1;
  state.stats.seenModels[idea.model.name] = (state.stats.seenModels[idea.model.name]||0) + 1;

  if (action === "save") {
    if (!state.saved.find(x=>x.id===idea.id)) {
      state.saved.unshift(idea);
      state.stats.saves++;
      buzz([10,30,10]); beep(880,.12,"triangle",.05); beep(1320,.08,"triangle",.04);
      toast(`⭐ Saved to vault (${state.saved.length})`);
      refreshBadges();
    }
  } else if (action === "like") {
    state.stats.likes++;
    buzz(14); beep(520,.06,"sine",.03);
    toast("Interesting — next one cooking");
  } else {
    state.stats.passes++;
    buzz(8); beep(220,.05,"sawtooth",.02);
  }
  persist();

  // Advance
  setTimeout(()=>{
    state.queue.shift();
    prefill();
    renderDeck();
  }, 320);
}

function refreshBadges(){
  const b = $("#tab-vault .badge");
  if (state.saved.length){
    b.textContent = state.saved.length > 99 ? "99+" : state.saved.length;
    b.style.display = "";
  } else {
    b.style.display = "none";
  }
}

// -------- Action buttons --------
$(".act.pass").onclick = ()=> {
  const el = deck.lastElementChild; if (!el || !state.current) return;
  el.style.transition = "transform .42s var(--ease-spring), opacity .35s";
  el.style.transform = "translate(-120vw,40px) rotate(-25deg)"; el.style.opacity = "0";
  commit("pass", state.current);
};
$(".act.like").onclick = ()=> {
  const el = deck.lastElementChild; if (!el || !state.current) return;
  el.style.transition = "transform .42s var(--ease-spring), opacity .35s";
  el.style.transform = "translate(120vw,40px) rotate(25deg)"; el.style.opacity = "0";
  commit("like", state.current);
};
$(".act.save").onclick = ()=> {
  const el = deck.lastElementChild; if (!el || !state.current) return;
  el.style.transition = "transform .42s var(--ease-spring), opacity .35s";
  el.style.transform = "translate(0,-120vh) rotate(0deg)"; el.style.opacity = "0";
  commit("save", state.current);
};
$(".act.detail").onclick = ()=> { if (state.current) openDetail(state.current); };
$(".act.reroll").onclick = ()=> {
  state.queue = [];
  prefill();
  renderDeck();
  toast("🎲 Rerolled the deck");
  buzz(12);
};

// -------- Tabs --------
function switchTab(name){
  $$(".tab").forEach(t=>t.classList.toggle("active", t.dataset.tab===name));
  $$(".view").forEach(v=>v.classList.toggle("active", v.id===name));
  if (name==="vault") renderVault();
  if (name==="stats") renderStats();
  buzz(6);
}
$$(".tab").forEach(t=>t.onclick = ()=>switchTab(t.dataset.tab));

// -------- Vault --------
function renderVault(){
  const list = $("#vault-list");
  const empty = $("#vault-empty");
  if (!state.saved.length){
    list.style.display = "none";
    empty.style.display = "";
    return;
  }
  list.style.display = "";
  empty.style.display = "none";
  list.innerHTML = state.saved.map(idea => `
    <div class="vault-item" data-id="${idea.id}">
      <div class="emj">${idea.emoji}</div>
      <div class="meta">
        <h3>${escapeHtml(idea.name)}<span class="t">${idea.tier}</span></h3>
        <p>${escapeHtml(idea.model.name)} · ${escapeHtml(idea.niche.name)}</p>
      </div>
      <div class="rev">${fmt$(idea.year1Revenue)}/y1</div>
    </div>
  `).join("");
  list.querySelectorAll(".vault-item").forEach(row=>{
    row.onclick = ()=>{
      const idea = state.saved.find(x=>x.id===row.dataset.id);
      if (idea) openDetail(idea, /*fromVault*/true);
    };
  });
}

// -------- Stats --------
function renderStats(){
  const s = state.stats;
  const saveRate = s.swipes ? Math.round(100 * s.saves / s.swipes) : 0;
  const totalY1 = state.saved.reduce((a,i)=>a+i.year1Revenue,0);
  const bestIdea = state.saved.slice().sort((a,b)=>b.score-a.score)[0];

  $("#kpi-swipes").textContent = s.swipes;
  $("#kpi-saves").textContent  = state.saved.length;
  $("#kpi-rate").textContent   = saveRate + "%";
  $("#kpi-portfolio").textContent = fmt$(totalY1);

  // Niches breakdown
  const topNiches = Object.entries(s.seenNiches).sort((a,b)=>b[1]-a[1]).slice(0,6);
  const max = Math.max(1, ...topNiches.map(x=>x[1]));
  $("#niche-breakdown").innerHTML = topNiches.length ? topNiches.map(([k,v])=>`
    <div>
      <div class="niche-bar"><span>${escapeHtml(k)}</span><span>${v}</span></div>
      <div class="bar-fill" style="width:${(v/max)*100}%"></div>
    </div>
  `).join("") : `<p style="color:var(--ink-mute);font-size:13px">Swipe through a few ideas to reveal your interests.</p>`;

  $("#best-idea").innerHTML = bestIdea ? `
    <div style="display:flex;gap:12px;align-items:center">
      <div class="emj" style="width:42px;height:42px;border-radius:12px;background:rgba(255,255,255,.06);display:grid;place-items:center;font-size:22px;border:1px solid var(--stroke)">${bestIdea.emoji}</div>
      <div style="flex:1;min-width:0">
        <div style="font-weight:700;font-size:15px">${escapeHtml(bestIdea.name)}</div>
        <div style="font-size:12px;color:var(--ink-dim)">Score ${bestIdea.score} · ${escapeHtml(bestIdea.tier)}</div>
      </div>
      <div style="font-weight:700;color:var(--accent-3);font-size:13px">${fmt$(bestIdea.year3Revenue)}/y3</div>
    </div>
  ` : `<p style="color:var(--ink-mute);font-size:13px">Save an idea to see your top pick.</p>`;
}

// -------- Detail modal --------
const backdrop = $("#backdrop");
const modal    = $("#modal");

function openDetail(idea, fromVault=false){
  buzz(8);
  const isSaved = state.saved.find(x=>x.id===idea.id);
  modal.querySelector(".scroll").innerHTML = `
    <div style="display:flex;align-items:center;gap:14px;margin-bottom:10px">
      <div style="width:56px;height:56px;border-radius:16px;background:linear-gradient(135deg,rgba(255,255,255,.2),rgba(255,255,255,.02));display:grid;place-items:center;font-size:30px;border:1px solid var(--stroke-strong)">${idea.emoji}</div>
      <div style="flex:1;min-width:0">
        <h2 style="font-size:22px">${escapeHtml(idea.name)}</h2>
        <div class="sub" style="margin:0">${idea.model.emoji} ${escapeHtml(idea.model.name)} · ${escapeHtml(idea.niche.name)} · ${escapeHtml(idea.audience)}</div>
      </div>
      <span class="tier ${idea.tier}" style="position:static">${idea.tierEmoji} ${escapeHtml(idea.tier)}</span>
    </div>

    <div class="tagline-box">${escapeHtml(idea.tagline)}</div>

    <h4>Revenue projection</h4>
    <div class="rev-row">
      <div class="rev-box"><div class="k">Year 1</div><div class="v">${fmt$(idea.year1Revenue)}</div></div>
      <div class="rev-box y3"><div class="k">Year 3</div><div class="v">${fmt$(idea.year3Revenue)}</div></div>
    </div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:10px">
      <div class="rev-box" style="background:rgba(255,255,255,.04);border-color:var(--stroke)"><div class="k">Price point</div><div class="v" style="font-size:18px">$${idea.price}${["SaaS subscription","paid community","newsletter (paid)","mobile app","AI agent service","freemium tool","subscription box"].includes(idea.model.name) ? "/mo" : ""}</div></div>
      <div class="rev-box" style="background:rgba(255,255,255,.04);border-color:var(--stroke)"><div class="k">Gross margin</div><div class="v" style="font-size:18px">${idea.margin}%</div></div>
    </div>

    <h4>90-day action plan</h4>
    <ol>${idea.actionPlan.map(s=>`<li>${escapeHtml(s)}</li>`).join("")}</ol>

    <h4>Skills you'll need</h4>
    <div class="skill-row">${idea.skills.map(s=>`<span>${escapeHtml(s)}</span>`).join("")}</div>

    <h4>Potential moats</h4>
    <ul>${idea.moats.map(m=>`<li>${escapeHtml(m)}</li>`).join("")}</ul>

    <h4>Risks to watch</h4>
    <ul>${idea.risks.map(r=>`<li>${escapeHtml(r)}</li>`).join("")}</ul>

    <div class="btn-row">
      <button class="btn" id="btn-share">📤 Share</button>
      ${fromVault
        ? `<button class="btn danger" id="btn-remove">🗑️ Remove</button>`
        : `<button class="btn primary" id="btn-save">${isSaved?"✓ In vault":"⭐ Save to vault"}</button>`}
    </div>
  `;

  backdrop.classList.add("open");
  modal.classList.add("open");

  modal.querySelector("#btn-share").onclick = ()=> shareIdea(idea);
  const saveBtn = modal.querySelector("#btn-save");
  if (saveBtn) saveBtn.onclick = ()=>{
    if (!state.saved.find(x=>x.id===idea.id)){
      state.saved.unshift(idea);
      state.stats.saves++;
      persist();
      refreshBadges();
      saveBtn.textContent = "✓ In vault";
      buzz([10,30,10]); beep(880,.12,"triangle",.05); beep(1320,.08,"triangle",.04);
      toast("⭐ Saved to vault");
    }
  };
  const removeBtn = modal.querySelector("#btn-remove");
  if (removeBtn) removeBtn.onclick = ()=>{
    state.saved = state.saved.filter(x=>x.id!==idea.id);
    persist(); refreshBadges(); renderVault();
    closeModal();
    toast("Removed from vault");
    buzz(10);
  };
}
function closeModal(){
  backdrop.classList.remove("open");
  modal.classList.remove("open");
}
backdrop.onclick = closeModal;

// swipe-down to close modal
(function attachModalSwipe(){
  let sy=0, dy=0, dragging=false;
  modal.addEventListener("touchstart", e=>{
    if (!modal.classList.contains("open")) return;
    if (modal.querySelector(".scroll").scrollTop > 2) return;
    dragging = true; sy = e.touches[0].clientY; dy = 0;
    modal.style.transition = "none";
  });
  modal.addEventListener("touchmove", e=>{
    if (!dragging) return;
    dy = Math.max(0, e.touches[0].clientY - sy);
    modal.style.transform = `translateY(${dy}px)`;
  },{passive:true});
  modal.addEventListener("touchend", ()=>{
    if (!dragging) return;
    dragging = false;
    modal.style.transition = "";
    if (dy > 140) closeModal();
    else modal.style.transform = "";
  });
})();

function shareIdea(idea){
  const text = `💡 ${idea.name}\n${idea.tagline}\n\n• Y1 revenue: ${fmt$(idea.year1Revenue)}\n• Startup: ${fmt$(idea.startupCost)}\n• Market: $${idea.marketSize}B · ${idea.growthRate}% YoY\n\n— via Profit Prophet`;
  if (navigator.share){
    navigator.share({title: idea.name, text}).catch(()=>copyFallback(text));
  } else copyFallback(text);
}
function copyFallback(text){
  navigator.clipboard?.writeText(text).then(()=>toast("📋 Copied to clipboard")).catch(()=>toast("Share unavailable"));
}

// -------- Onboarding --------
$("#onboard-cta").onclick = ()=>{
  $("#onboard").classList.add("hide");
  setTimeout(()=>$("#onboard").remove(), 520);
  buzz([14,40,14]); beep(660,.08,"triangle",.05); beep(990,.08,"triangle",.04);
};
if (localStorage.getItem("pp_onboarded")) $("#onboard")?.remove();
else localStorage.setItem("pp_onboarded","1");

// -------- Init --------
prefill(4);
renderDeck();
refreshBadges();

// Keyboard shortcuts (desktop preview)
window.addEventListener("keydown", e=>{
  if (e.target.tagName==="INPUT") return;
  if (e.key==="ArrowLeft") $(".act.pass").click();
  if (e.key==="ArrowRight") $(".act.like").click();
  if (e.key==="ArrowUp") $(".act.save").click();
  if (e.key==="d") $(".act.detail").click();
  if (e.key==="r") $(".act.reroll").click();
});

// Service worker (PWA)
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("./sw.js").catch(()=>{});
}
