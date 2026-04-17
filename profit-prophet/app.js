// SCRY — app logic
const $  = (s,r=document)=>r.querySelector(s);
const $$ = (s,r=document)=>Array.from(r.querySelectorAll(s));

// ---------- State ----------
const STORE_KEY = "scry_v2";
const state = loadState();

function loadState(){
  try {
    const raw = JSON.parse(localStorage.getItem(STORE_KEY) || "null");
    if (raw) return raw;
  } catch(_){}
  return {
    user: null, // {name, dob, intent}
    onboarded: false,
    streak: 0, bestStreak: 0,
    lastOpen: null,    // YYYY-MM-DD
    activeDays: [],    // array of YYYY-MM-DD
    collection: [],    // cards pulled
    daily: null,       // last daily card
    dailyDate: null,
    pullsPerDeck: {},  // {love: 12, fortune: 3, ...}
    settings: { sound:true, haptics:true },
  };
}
function save(){ localStorage.setItem(STORE_KEY, JSON.stringify(state)); }

// ---------- Helpers ----------
function today(){ return new Date().toISOString().slice(0,10); }
function buzz(p){ if (state.settings.haptics) try { navigator.vibrate?.(p); } catch(_){} }
let ac;
function tone(freq=660, dur=.15, type="sine", vol=.05){
  if (!state.settings.sound) return;
  try {
    ac = ac || new (window.AudioContext||window.webkitAudioContext)();
    const o = ac.createOscillator(); const g = ac.createGain();
    o.type = type; o.frequency.value = freq;
    g.gain.setValueAtTime(0, ac.currentTime);
    g.gain.linearRampToValueAtTime(vol, ac.currentTime+.015);
    g.gain.exponentialRampToValueAtTime(.0001, ac.currentTime+dur);
    o.connect(g).connect(ac.destination);
    o.start(); o.stop(ac.currentTime+dur);
  } catch(_){}
}
function chord(freqs, dur=.5, type="sine", vol=.04){
  freqs.forEach(f => tone(f, dur, type, vol));
}
function shine(){
  const s = document.createElement("div");
  s.className = "myth-shine";
  document.body.appendChild(s);
  setTimeout(()=>s.remove(), 900);
}
let toastTimer;
function toast(msg){
  const t = $("#toast");
  t.textContent = msg;
  t.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(()=>t.classList.remove("show"), 1900);
}
function escapeHtml(s){return String(s).replace(/[&<>"']/g, c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));}
function fmtDate(d){
  const dt = new Date(d+"T00:00");
  return dt.toLocaleDateString(undefined,{weekday:"long",month:"short",day:"numeric"});
}

// ---------- Starfield ----------
(function stars(){
  const c = $("#stars"), ctx = c.getContext("2d");
  let w,h,st=[];
  function fit(){ w = c.width = innerWidth*devicePixelRatio; h = c.height = innerHeight*devicePixelRatio;
    c.style.width = innerWidth+"px"; c.style.height = innerHeight+"px"; }
  fit(); addEventListener("resize", fit);
  const N = 110;
  for (let i=0;i<N;i++){
    st.push({
      x:Math.random()*w, y:Math.random()*h,
      r:(Math.random()*1.2+.2)*devicePixelRatio,
      v:Math.random()*.5+.1,
      tw:Math.random()*Math.PI*2,
      tc:Math.random()<.18
    });
  }
  function tick(){
    ctx.clearRect(0,0,w,h);
    for (const s of st){
      s.tw += 0.03;
      const a = (Math.sin(s.tw)*.5+.5)*.8+.2;
      ctx.beginPath();
      ctx.arc(s.x, s.y, s.r, 0, Math.PI*2);
      ctx.fillStyle = s.tc ? `rgba(255,209,102,${a})` : `rgba(255,255,255,${a*.85})`;
      ctx.fill();
      if (s.r > devicePixelRatio){
        ctx.beginPath();
        ctx.arc(s.x,s.y,s.r*3,0,Math.PI*2);
        ctx.fillStyle = s.tc ? `rgba(255,209,102,${a*.15})` : `rgba(167,139,250,${a*.18})`;
        ctx.fill();
      }
      s.y += s.v*.06;
      if (s.y > h) s.y = 0;
    }
    requestAnimationFrame(tick);
  }
  tick();
})();

// ---------- Onboarding ----------
function syncCTA(){
  const s = currentStep();
  const btn = $("#onb-cta");
  btn.textContent = s === 2 ? "Begin the ritual →" : "Next →";
  btn.disabled =
    (s === 0 && !$("#onb-name").value.trim()) ||
    (s === 1 && !$("#onb-dob").value) ||
    (s === 2 && !$$(".intent.sel").length);
}
function currentStep(){
  return Number($$(".step.active")[0]?.dataset.step || 0);
}
function goStep(n){
  $$(".step").forEach(s => s.classList.toggle("active", Number(s.dataset.step) === n));
  syncCTA();
}
$("#onb-name").addEventListener("input", syncCTA);
$("#onb-dob").addEventListener("input", syncCTA);
$$(".intent").forEach(i => i.addEventListener("click", ()=>{
  $$(".intent").forEach(x=>x.classList.remove("sel"));
  i.classList.add("sel"); buzz(8); tone(880,.08,"triangle",.04);
  syncCTA();
}));
$("#onb-cta").addEventListener("click", ()=>{
  const s = currentStep();
  if (s < 2) { goStep(s+1); buzz(8); tone(660,.08,"triangle",.04); return; }
  // finalize
  state.user = {
    name: $("#onb-name").value.trim(),
    dob: $("#onb-dob").value,
    intent: $$(".intent.sel")[0]?.dataset.intent || "clarity",
  };
  state.onboarded = true;
  save();
  $("#onb").classList.add("hide");
  chord([440, 660, 880], .45, "sine", .04);
  buzz([14,40,14]);
  setTimeout(()=>{ $("#onb").remove(); enterApp(); }, 640);
});

// ---------- App init ----------
function enterApp(){
  $("#app").hidden = false;
  refreshUser();
  updateStreak();
  renderDaily();
  renderDeckMetas();
  renderCollection();
  renderMe();
  cycleWhisper();
  setInterval(cycleWhisper, 7000);
}
function refreshUser(){
  const u = state.user || { name:"seeker" };
  $("#hi-name").textContent = u.name || "seeker";
  $("#me-name").textContent = u.name || "seeker";
  $("#me-sub").textContent = u.dob ? `${u.intent} · born ${u.dob}` : (u.intent || "");
  $("#me-sigil").textContent = (u.name||"S").slice(0,1).toUpperCase();
}

// ---------- Streak + calendar ----------
function updateStreak(){
  const t = today();
  if (state.lastOpen !== t){
    // Is it consecutive?
    const prev = state.lastOpen;
    if (prev){
      const d1 = new Date(prev+"T00:00"); const d2 = new Date(t+"T00:00");
      const diff = Math.round((d2 - d1)/86400000);
      if (diff === 1) state.streak = (state.streak||0)+1;
      else if (diff > 1) state.streak = 1;
    } else {
      state.streak = 1;
    }
    state.bestStreak = Math.max(state.bestStreak||0, state.streak);
    if (!state.activeDays.includes(t)) state.activeDays.push(t);
    if (state.activeDays.length > 400) state.activeDays = state.activeDays.slice(-400);
    state.lastOpen = t;
    save();
    if (state.streak > 1) toast(`🔥 ${state.streak}-day streak`);
  }
  $("#streak-num").textContent = state.streak || 0;
}

// ---------- Daily card ----------
function renderDaily(){
  const t = today();
  const tc = $("#today-card");
  $("#today-date").textContent = fmtDate(t);
  if (state.dailyDate === t && state.daily){
    const c = state.daily;
    tc.classList.add("revealed");
    tc.style.setProperty("--c1", c.c1);
    tc.style.setProperty("--c2", c.c2);
    $("#tc-sigil").textContent = c.sym;
    $("#tc-title").textContent = c.title;
    $("#tc-sub").textContent = c.body;
    tc.onclick = ()=> openReveal(c, {skipShuffle:true, label:"daily"});
  } else {
    tc.classList.remove("revealed");
    tc.style.removeProperty("--c1"); tc.style.removeProperty("--c2");
    $("#tc-sigil").textContent = "✦";
    $("#tc-title").textContent = "Tap to reveal today";
    $("#tc-sub").textContent = "one card per day · the day's fate awaits";
    tc.onclick = ()=> {
      const c = drawDaily(state.user);
      state.daily = c; state.dailyDate = today();
      addToCollection(c);
      save();
      openReveal(c, {label:"today's fate", isDaily:true});
    };
  }
}

// ---------- Decks ----------
function renderDeckMetas(){
  Object.keys(DECKS).forEach(k=>{
    const el = document.getElementById("m-"+k);
    if (el) el.textContent = (state.pullsPerDeck?.[k] || 0) + " pulled";
  });
}
$$(".deck").forEach(d => d.addEventListener("click", ()=>{
  const deckKey = d.dataset.deck;
  const c = drawFrom(deckKey, state.user);
  state.pullsPerDeck[deckKey] = (state.pullsPerDeck[deckKey]||0)+1;
  addToCollection(c);
  save();
  renderDeckMetas();
  openReveal(c, {label:DECKS[deckKey].label});
}));

function addToCollection(c){
  state.collection.unshift(c);
  if (state.collection.length > 300) state.collection.length = 300;
}

// ---------- Reveal ritual ----------
function openReveal(card, opts={}){
  const r = $("#reveal");
  r.hidden = false;
  document.body.style.overflow = "hidden";
  const shuf = $("#rev-shuffle"), breath = $("#rev-breath"), cb = $("#rev-card"), acts = $("#rev-actions");
  cb.classList.remove("flip","rare","mythic");
  cb.hidden = true; acts.hidden = true;
  buzz(12); tone(440,.1,"sine",.04);

  if (opts.skipShuffle){
    shuf.hidden = true; breath.hidden = true;
    setTimeout(()=>showCard(card, opts), 50);
    return;
  }

  // 1. shuffle
  shuf.hidden = false; breath.hidden = true;
  chord([220,330], .6, "sine", .03);
  setTimeout(()=>{
    shuf.hidden = true;
    // 2. breath
    breath.hidden = false;
    const phases = ["breathe in…","hold…","breathe out…","now — ask"];
    let idx = 0;
    $("#breath-label").textContent = phases[idx];
    buzz(10);
    tone(330,.2,"sine",.03);
    const tickInt = setInterval(()=>{
      idx++;
      if (idx >= phases.length){ clearInterval(tickInt); return; }
      $("#breath-label").textContent = phases[idx];
      tone(330 + idx*55, .2, "sine", .03);
      buzz(10);
    }, 1400);
    const next = ()=>{
      breath.hidden = true; clearInterval(tickInt);
      showCard(card, opts);
    };
    // advance after animation OR on tap
    const timeout = setTimeout(next, 6200);
    breath.onclick = ()=> { clearTimeout(timeout); next(); };
  }, 1600);
}

function showCard(card, opts){
  const cb = $("#rev-card"), acts = $("#rev-actions");
  cb.hidden = false;
  const back = cb.querySelector(".back");
  back.style.setProperty("--c1", card.c1);
  back.style.setProperty("--c2", card.c2);
  cb.querySelector(".cb-tier").textContent = `${opts.label || card.deckLabel} · ${card.tier}`;
  cb.querySelector(".cb-sym").textContent = card.sym;
  cb.querySelector(".cb-title").textContent = card.title;
  cb.querySelector(".cb-body").textContent = card.body;
  cb.querySelector(".cb-foot").textContent = `SCRY · ${fmtDate(card.date || today())}`;

  cb.classList.add(card.tier);

  // Tap card to flip
  cb.onclick = flipOnce;
  // Auto-flip after a beat on daily
  setTimeout(flipOnce, opts.isDaily ? 700 : 400);

  function flipOnce(){
    if (cb.classList.contains("flip")) return;
    cb.classList.add("flip");
    cb.onclick = null;
    buzz([20,40,60]);
    if (card.tier === "mythic"){ shine(); chord([523,659,784,988],.9,"triangle",.05); buzz([30,50,30,50,30]); }
    else if (card.tier === "rare"){ chord([523,659,784],.6,"sine",.04); }
    else { chord([523,659],.5,"sine",.04); }
    setTimeout(()=>{ acts.hidden = false; }, 600);
  }
}

$("#btn-close").addEventListener("click", closeReveal);
$("#btn-share").addEventListener("click", shareCard);
function closeReveal(){
  $("#reveal").hidden = true;
  document.body.style.overflow = "";
  // refresh views
  renderCollection();
  renderMe();
  renderDaily();
  buzz(8);
}
async function shareCard(){
  const card = currentRevealedCard();
  if (!card) return;
  const text = `"${card.title}"\n${card.body}\n\n— SCRY · ${card.deckLabel} · ${card.tier}`;
  // Try rendering a PNG first
  try {
    const blob = await renderCardPNG(card);
    if (blob && navigator.canShare && navigator.canShare({ files: [new File([blob], "scry.png", {type:"image/png"})] })){
      const file = new File([blob], `scry-${card.id}.png`, { type:"image/png" });
      await navigator.share({ files:[file], text, title:"SCRY" });
      toast("shared"); return;
    }
  } catch(_) {}
  if (navigator.share) { try { await navigator.share({ text, title:"SCRY" }); toast("shared"); return; } catch(_){} }
  navigator.clipboard?.writeText(text).then(()=>toast("copied to clipboard")).catch(()=>toast("share unavailable"));
}
function currentRevealedCard(){
  // The latest card pushed onto the collection
  return state.collection[0];
}

// ---------- Card → PNG for sharing ----------
function renderCardPNG(card){
  return new Promise((resolve,reject)=>{
    try {
      const W = 720, H = 1280;
      const c = document.createElement("canvas");
      c.width = W; c.height = H;
      const x = c.getContext("2d");
      // background
      const g = x.createLinearGradient(0,0,W,H);
      g.addColorStop(0, card.c1); g.addColorStop(1, card.c2);
      x.fillStyle = "#05050a"; x.fillRect(0,0,W,H);
      // frame
      const fx = 60, fy = 120, fw = W-120, fh = H-240;
      x.fillStyle = g;
      roundRect(x, fx, fy, fw, fh, 44); x.fill();
      // inner dark overlay
      const og = x.createLinearGradient(0, fy, 0, fy+fh);
      og.addColorStop(0, "rgba(0,0,0,0)"); og.addColorStop(1, "rgba(0,0,0,.35)");
      x.fillStyle = og; roundRect(x, fx, fy, fw, fh, 44); x.fill();
      // tier line
      x.fillStyle = "rgba(255,255,255,.85)";
      x.font = "600 22px 'Inter',system-ui,sans-serif";
      x.textAlign = "center";
      x.fillText(`${card.deckLabel.toUpperCase()} · ${card.tier.toUpperCase()}`, W/2, fy+60);
      // sym
      x.font = "140px system-ui";
      x.fillText(card.sym, W/2, fy+260);
      // title
      x.fillStyle = "#fff";
      x.font = "900 54px 'Inter',system-ui,sans-serif";
      wrapText(x, card.title, W/2, fy+360, fw-100, 60);
      // body
      x.fillStyle = "rgba(255,255,255,.92)";
      x.font = "italic 400 28px 'Inter',system-ui,sans-serif";
      wrapText(x, card.body, W/2, fy+500, fw-100, 38);
      // footer
      x.fillStyle = "rgba(255,255,255,.75)";
      x.font = "700 20px 'Inter',system-ui,sans-serif";
      x.fillText("SCRY · what the stars forgot to say", W/2, fy+fh-30);
      c.toBlob(b => b ? resolve(b) : reject(new Error("blob failed")), "image/png");
    } catch(e){ reject(e); }
  });
}
function roundRect(x, rx, ry, rw, rh, r){
  x.beginPath();
  x.moveTo(rx+r, ry);
  x.arcTo(rx+rw, ry, rx+rw, ry+rh, r);
  x.arcTo(rx+rw, ry+rh, rx, ry+rh, r);
  x.arcTo(rx, ry+rh, rx, ry, r);
  x.arcTo(rx, ry, rx+rw, ry, r);
  x.closePath();
}
function wrapText(ctx, text, cx, cy, maxW, lineH){
  const words = text.split(" "); let line = "", y = cy;
  for (const w of words){
    const test = line ? line + " " + w : w;
    if (ctx.measureText(test).width > maxW && line){
      ctx.fillText(line, cx, y); line = w; y += lineH;
    } else line = test;
  }
  if (line) ctx.fillText(line, cx, y);
}

// ---------- Collection ----------
function renderCollection(){
  const list = state.collection;
  const grid = $("#coll-grid");
  const empty = $("#coll-empty");
  const badge = $("#tab-badge");
  if (!list.length){ grid.innerHTML = ""; empty.hidden = false; badge.hidden = true; }
  else {
    empty.hidden = true;
    badge.hidden = false; badge.textContent = list.length > 99 ? "99+" : list.length;
    grid.innerHTML = list.slice(0,96).map(c => `
      <div class="mini ${c.tier}" data-id="${c.id}" style="--a:${c.c1}">
        <div class="ms">${c.sym}</div>
        <div>
          <div class="mt">${escapeHtml(c.title)}</div>
          <div class="md">${escapeHtml(c.deckLabel)} · ${c.tier}</div>
        </div>
      </div>
    `).join("");
    grid.querySelectorAll(".mini").forEach(el=>{
      el.onclick = ()=>{
        const c = state.collection.find(x=>x.id === el.dataset.id);
        if (c) openReveal(c, { skipShuffle:true, label:c.deckLabel });
      };
    });
  }
  $("#cs-total").textContent = list.length;
  $("#cs-rare").textContent  = list.filter(c=>c.tier==="rare").length;
  $("#cs-myth").textContent  = list.filter(c=>c.tier==="mythic").length;
  $("#cs-best").textContent  = state.bestStreak || 0;
}

// ---------- Me / calendar / signature ----------
function renderMe(){
  // signature: derived from pulls-per-deck + intent
  const totals = state.pullsPerDeck || {};
  const top = Object.entries(totals).sort((a,b)=>b[1]-a[1])[0];
  const topName = top ? DECKS[top[0]].label : "—";
  const n = state.collection.length;
  const u = state.user || {};
  const traits = [];
  if (n > 20) traits.push("a dedicated seeker");
  if (n <= 3) traits.push("just beginning");
  if (top?.[0] === "love") traits.push("drawn to the heart's questions");
  if (top?.[0] === "fortune") traits.push("tuned to abundance");
  if (top?.[0] === "dare") traits.push("ready for movement");
  if (top?.[0] === "mirror") traits.push("committed to self-inquiry");
  if (top?.[0] === "pastlife") traits.push("fascinated by origins");
  if (top?.[0] === "shadow") traits.push("unafraid of the deep water");
  if (!traits.length) traits.push("newly arrived");
  $("#me-signature").innerHTML = `
    <b>${escapeHtml(u.name || "seeker")}</b> — intention of <b>${escapeHtml(u.intent||"clarity")}</b>.
    Most drawn to the <b>${escapeHtml(topName)}</b> deck.
    The oracle sees you as <b>${traits.slice(0,2).join(", ")}</b>.
  `;

  // calendar: last 35 days
  const cal = $("#cal");
  const now = new Date();
  const cells = [];
  const tdy = today();
  const set = new Set(state.activeDays);
  for (let i=34;i>=0;i--){
    const d = new Date(now.getTime() - i*86400000);
    const iso = d.toISOString().slice(0,10);
    const isToday = iso === tdy;
    const done = set.has(iso);
    cells.push(`<div class="c ${done?'done':''} ${isToday?'today':''}" title="${iso}">${d.getDate()}</div>`);
  }
  cal.innerHTML = cells.join("");

  $("#t-sound").checked = !!state.settings.sound;
  $("#t-haptics").checked = !!state.settings.haptics;
}
$("#t-sound").addEventListener("change", e=>{ state.settings.sound = e.target.checked; save(); });
$("#t-haptics").addEventListener("change", e=>{ state.settings.haptics = e.target.checked; save(); });
$("#reset-btn").addEventListener("click", ()=>{
  if (confirm("Reset everything? This erases your deck, streak, and profile.")){
    localStorage.removeItem(STORE_KEY);
    location.reload();
  }
});

// ---------- Tabs ----------
$$(".tab").forEach(t => t.addEventListener("click", ()=>{
  const v = t.dataset.view;
  $$(".tab").forEach(x=>x.classList.toggle("active", x === t));
  $$(".view").forEach(s => s.classList.toggle("active", s.id === "v-"+v));
  buzz(6); tone(520,.05,"triangle",.03);
  if (v === "collection") renderCollection();
  if (v === "me") renderMe();
}));

// ---------- Whispers ----------
function cycleWhisper(){
  const el = $("#whispers");
  if (!el) return;
  el.style.opacity = 0;
  setTimeout(()=>{ el.textContent = randomWhisper(state.user); el.style.opacity = 1; }, 450);
}

// ---------- Compatibility ----------
$("#open-compat").addEventListener("click", ()=>{
  $("#compat").hidden = false;
  requestAnimationFrame(()=> $("#compat").classList.add("open"));
  buzz(8);
});
$("#c-close").addEventListener("click", closeCompat);
function closeCompat(){
  $("#compat").classList.remove("open");
  setTimeout(()=>{ $("#compat").hidden = true; }, 400);
}
$("#c-go").addEventListener("click", ()=>{
  const b = { name: $("#c-name").value.trim(), dob: $("#c-dob").value };
  if (!b.name){ toast("enter a name first"); return; }
  const score = compatScore(state.user, b);
  const r = compatReading(state.user, b, score, state.user);
  const box = $("#c-result");
  box.hidden = false;
  box.innerHTML = `
    <div class="label">${escapeHtml(r.label)}</div>
    <div class="score">${score}%</div>
    <div class="body">${escapeHtml(r.body)}</div>
  `;
  buzz([14,40,14]);
  if (score >= 85) { shine(); chord([523,659,784,988],.9,"triangle",.05); }
  else chord([440,554,660],.5,"sine",.04);
});

// ---------- Boot ----------
if (state.onboarded && state.user){
  $("#onb").remove();
  enterApp();
} else {
  goStep(0);
}

// PWA SW
if ("serviceWorker" in navigator){
  navigator.serviceWorker.register("./sw.js").catch(()=>{});
}

// Keyboard for desktop
addEventListener("keydown", e => {
  if (e.target.tagName === "INPUT") return;
  if (e.key === "Escape") { if (!$("#reveal").hidden) closeReveal(); if (!$("#compat").hidden) closeCompat(); }
});
