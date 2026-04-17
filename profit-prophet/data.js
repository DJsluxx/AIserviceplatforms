// SCRY — card generation engine. Variable-reward slot machine logic.

const DECKS = {
  love: {
    sigil: "♡", c1: "#f472b6", c2: "#3a1d3a", label: "Love",
    symbols: ["❤","🌹","💫","🕊️","🌙","💋","🔮","💍","🗝","🌸"],
    cards: [
      { t:"The Unsent Text", b:"Someone is composing a message to {name} they'll never send. What you don't know changes you anyway."},
      { t:"Twin Flame Hour", b:"Look at the clock tonight at 22:22. That's when they'll think of you."},
      { t:"The Returning", b:"A person you loved in {month} is closer to coming back than you think."},
      { t:"Silent Knowing", b:"The next time you doubt if they love you, notice how their body is pointed when you speak."},
      { t:"Red String", b:"A cord runs from your chest to someone you haven't met. It shortens this week."},
      { t:"The Mirror", b:"What you want in love is what you haven't yet given yourself. Start with {intent}."},
      { t:"Deja Vu", b:"You will feel it before they do. Do not speak first — let them find the courage."},
      { t:"Old Soul", b:"This isn't the first lifetime you've circled each other, {name}. It will not be the last."},
      { t:"The Garden", b:"Tend what already grows. A new bloom will come when you stop transplanting yourself for others."},
      { t:"Sealed", b:"A promise made silently in your seventeenth year is about to be answered."},
      { t:"Moonwater", b:"Love is not the loudest feeling. It's the one that survives being ignored."},
      { t:"Eclipse", b:"The person blocking your light is about to move. The sky clears by {month}'s end."},
      { t:"The Other Room", b:"Someone is in the next room — literally or metaphorically — waiting for you to open the door."},
      { t:"Unrequited", b:"If love isn't being returned, you're burning candles on an empty altar. Blow them out, {name}."},
      { t:"The Vow", b:"Don't make them prove it again. Believe it the first time — or leave."},
    ],
  },
  fortune: {
    sigil: "◈", c1: "#ffd166", c2: "#3a2a0d", label: "Fortune",
    symbols: ["💰","🗝","⚜","💎","🏺","🌾","🔑","☉","✨","📜"],
    cards: [
      { t:"The Envelope", b:"Money is closer than the calendar suggests. Check a place you stopped checking, {name}."},
      { t:"Old Debt", b:"Someone owes you — not always money. Ask, and you'll be surprised what returns."},
      { t:"The Seed", b:"An offer in {month} looks small. It isn't. Say yes with a clean heart."},
      { t:"Forked Road", b:"Two paths appear. The one that scares you a little is the richer one."},
      { t:"Windfall", b:"A sum will enter your life unexpectedly within a moon's turn. Don't spend it the day it arrives."},
      { t:"The Deal", b:"Renegotiate. What you signed, accepted, or agreed to — it's time to ask for more."},
      { t:"Slow Gold", b:"The quickest money leaves the quickest. Choose the slow route this season, {name}."},
      { t:"Gatekeeper", b:"A person thinks they block your abundance. They don't. Walk past them politely."},
      { t:"The Key", b:"A skill you already own, barely used, becomes currency before the year turns."},
      { t:"Inheritance", b:"Not always from the dead. Something is passed down to you soon — a client, a role, a seat at a table."},
      { t:"Spend the Fear", b:"Money follows the brave. Invest in the version of yourself you're pretending not to be."},
      { t:"Cracked Jar", b:"A small leak is draining you. Find the subscription, the habit, the person — and seal it."},
      { t:"The Emperor's Nod", b:"Someone in power has quietly noticed you. You will learn this after you stop performing for them."},
      { t:"Midas Hand", b:"For seven days, what you touch with focus turns. Choose one project — not three."},
      { t:"The Hidden Ledger", b:"You are richer than you think in one specific way. Audit your assets, not your anxieties."},
    ],
  },
  dare: {
    sigil: "⚡", c1: "#ef4444", c2: "#3a0d0d", label: "Dare",
    symbols: ["⚡","🔥","💥","👁","🎭","🗡","🏹","⚔","🎯","🚪"],
    cards: [
      { t:"Seven Words", b:"Today, tell one person exactly seven words of truth about how they affect you."},
      { t:"The Cold Plunge", b:"60 seconds of cold water before the sun sets. Your bloodline will feel it."},
      { t:"Unfollow Three", b:"Three accounts are stealing your mood. You know which. Cut them before tomorrow, {name}."},
      { t:"Say the Price", b:"Double what you were about to charge. Say it out loud once. Feel the room."},
      { t:"The Compliment", b:"Give one absurdly specific compliment to a stranger today. Watch what it does to them."},
      { t:"Phone in Another Room", b:"For two hours tonight, your phone is not in the same room as you. See what surfaces."},
      { t:"Old Message", b:"Open a conversation you left on read three years ago. Say one honest sentence."},
      { t:"The Chair", b:"Sit with yourself for ten minutes. No music. No phone. No distraction. The oracle starts speaking after minute six."},
      { t:"Wear the Thing", b:"That piece in your closet you're 'saving' — wear it today. Saving for what? {name}, for what?"},
      { t:"Walk Without a Destination", b:"Go outside. Walk until something surprises you. Don't come back until it does."},
      { t:"The No", b:"Say no to the next thing asked of you today. No explanation. No apology."},
      { t:"Record It", b:"Voice-memo yourself for 3 minutes about what you actually want this year. Don't delete it."},
      { t:"Ask for the Number", b:"Ask for it. Not next week. Today."},
      { t:"The Reset", b:"Delete one app for 24 hours. Pick the one that just made your stomach tighten when you read this."},
      { t:"The Hug", b:"Longer than you'd normally hold. Let the other person let go first."},
    ],
  },
  mirror: {
    sigil: "◉", c1: "#34d399", c2: "#0d3a2d", label: "Mirror",
    symbols: ["◉","🪞","👁","🌊","💭","🕳","🪷","🌿","☯","🧿"],
    cards: [
      { t:"Unasked Question", b:"What are you pretending not to know, {name}?"},
      { t:"The Doorframe", b:"Which door have you been standing in — neither leaving nor entering?"},
      { t:"Younger You", b:"If your 12-year-old self walked in right now, what would they pull on your sleeve to ask about?"},
      { t:"The Sentence", b:"Finish: 'I would feel free if I could finally admit that ___.'"},
      { t:"Your Inner Saboteur", b:"It has a voice. What does it sound like? Whose voice is it, really?"},
      { t:"The Permission", b:"What are you waiting for someone to give you permission to do? Who?"},
      { t:"Cost Ledger", b:"What is loyalty to that job / that person / that story costing you, in units other than money?"},
      { t:"The Apology You Owe", b:"Not the one you owe others. The one you owe yourself, from {month} of 2023."},
      { t:"The Trade", b:"You are trading time for something. Is the exchange rate still fair?"},
      { t:"What You Envy", b:"What you envy in others is a compass. What does yours point to?"},
      { t:"The Empty Chair", b:"Who sits in it, when you imagine your ideal Sunday dinner a year from now?"},
      { t:"Unmet Need", b:"What do you most wish someone would give you, that you are refusing to give yourself?"},
      { t:"Pattern", b:"In your last three relationships — romantic or otherwise — what role did you keep playing?"},
      { t:"The Outgrown Room", b:"Which room in your life was built for someone you used to be?"},
      { t:"Grief You Skipped", b:"What loss did you rush past? The oracle asks you to sit with it for 90 seconds."},
    ],
  },
  pastlife: {
    sigil: "♆", c1: "#d97706", c2: "#3a1f0d", label: "Past Life",
    symbols: ["🏺","⚱","🗿","📯","🐎","🕯","🗺","⚓","🏛","📜"],
    cards: [
      { t:"The Cartographer", b:"In 1641, {name}, you mapped coastlines that had no names. You died seeing an ocean no one believed existed."},
      { t:"The Herbalist", b:"You tended a garden in 9th-century Kyoto. The plant you're drawn to today was your oldest patient."},
      { t:"The Duelist", b:"Seventeenth-century Seville. You lost one argument — the rest, never. You still flinch at mirrors."},
      { t:"The Scribe", b:"You copied manuscripts in a Byzantine monastery by candlelight. That's why your handwriting still surprises you."},
      { t:"The Seamstress", b:"Paris, 1820s. You sewed dresses for women who couldn't afford them. Kindness survives the reincarnation."},
      { t:"The Watchman", b:"A tower above the Baltic Sea, 1400s. You kept a lantern lit for ships that never came. You still wait well."},
      { t:"The Thief", b:"Cairo, 890 CE. You stole only things no one had loved in a long time. Your ethics outlived your name."},
      { t:"The Dancer", b:"You performed in a Persian court and refused to marry the prince. The song you hummed then — you hum it now and don't know why."},
      { t:"The Beekeeper", b:"12th-century Cornwall. Your hands were always warm. That's not changed."},
      { t:"The Shipwright", b:"Norse coast, 800s. You built a boat that outlived your village. Something you build this year will do the same."},
      { t:"The Philosopher", b:"Athens, 350 BCE. You asked one question at a symposium that was still being argued about a century later."},
      { t:"The Midwife", b:"Rural Ireland, 1700s. You caught babies by firelight. You are still the one others reach for when life begins or ends."},
    ],
  },
  shadow: {
    sigil: "☽", c1: "#8b5cf6", c2: "#1e1b4b", label: "Shadow",
    symbols: ["☽","🌑","🕸","🦉","🜂","🜄","🕷","🌀","⚰","🗝"],
    cards: [
      { t:"The Pattern You Protect", b:"You defend a behavior you secretly hate. The oracle will not name it. You already know, {name}."},
      { t:"What You Inherited", b:"A fear you carry wasn't born in your body. Trace it upward. A grandparent left it in your bloodstream."},
      { t:"The Performance", b:"There is a version of you that exists only for other people's comfort. You built her young. She can rest now."},
      { t:"The Forbidden Want", b:"What do you want that you've decided you're not allowed to want? The oracle says: you are allowed."},
      { t:"Anger, Unopened", b:"You have a box of anger at a specific person that you haven't let yourself open. It's past time."},
      { t:"The Self You Hide", b:"Not the self others would judge. The self YOU would judge, if you met her at a party."},
      { t:"The Lie of Peace", b:"'I'm fine with it' is protecting you from something true. What?"},
      { t:"The Crack", b:"There is one friendship slowly breaking. You've been pretending not to hear it."},
      { t:"The Taken", b:"Someone took something from you that you never asked back for. Your quiet is paying interest on that debt."},
      { t:"Jealousy Map", b:"The jealousy you feel most often points to the life you haven't given yourself permission to want."},
      { t:"The Mask Slipped", b:"Recently, someone saw the real you. You panicked. They didn't leave. Believe that, {name}."},
      { t:"The Abandonment", b:"Not every door closing is a rejection. Some are being held open for your exit."},
    ],
  },
};

const TIERS = [
  { k:"common",  p:70, label:"common"  },
  { k:"rare",    p:24, label:"rare"    },
  { k:"mythic",  p:6,  label:"mythic"  },
];
function rollTier(){
  const r = Math.random()*100;
  let acc = 0;
  for (const t of TIERS){ acc += t.p; if (r <= acc) return t.k; }
  return "common";
}

const MONTHS = ["January","February","March","April","May","June","July","August","September","October","November","December"];

function fillTemplate(str, user){
  const month = MONTHS[Math.floor(Math.random()*12)];
  return str
    .replaceAll("{name}", user?.name || "traveler")
    .replaceAll("{month}", month)
    .replaceAll("{intent}", user?.intent || "clarity");
}

function hashStr(s){
  let h = 2166136261;
  for (let i=0;i<s.length;i++){ h ^= s.charCodeAt(i); h = (h*16777619)>>>0; }
  return h;
}
function seededRng(seed){
  let s = seed >>> 0;
  return () => { s = (s*1664525 + 1013904223)>>>0; return s / 0xffffffff; };
}

// Deterministic daily draw — same card all day for a given user
function drawDaily(user){
  const today = new Date().toISOString().slice(0,10);
  const seed = hashStr(today + "|" + (user?.name||"") + "|" + (user?.dob||""));
  const rng = seededRng(seed);
  // Daily uses a blend deck weighted toward intent
  const keys = Object.keys(DECKS);
  const deckKey = keys[Math.floor(rng()*keys.length)];
  const d = DECKS[deckKey];
  const card = d.cards[Math.floor(rng()*d.cards.length)];
  const sym = d.symbols[Math.floor(rng()*d.symbols.length)];
  // Daily is always at least rare
  const tier = rng() < .12 ? "mythic" : "rare";
  return {
    id: "daily:"+today,
    deck: deckKey, deckLabel: d.label,
    sigil: d.sigil, sym,
    c1: d.c1, c2: d.c2,
    tier, title: card.t, body: fillTemplate(card.b, user),
    daily: true, date: today,
  };
}

function drawFrom(deckKey, user){
  const d = DECKS[deckKey];
  const card = d.cards[Math.floor(Math.random()*d.cards.length)];
  const sym = d.symbols[Math.floor(Math.random()*d.symbols.length)];
  const tier = rollTier();
  return {
    id: deckKey + ":" + Date.now() + ":" + Math.random().toString(36).slice(2,6),
    deck: deckKey, deckLabel: d.label,
    sigil: d.sigil, sym,
    c1: d.c1, c2: d.c2,
    tier, title: card.t, body: fillTemplate(card.b, user),
    date: new Date().toISOString().slice(0,10),
  };
}

// Whispers — ambient background poetic text cycled
const WHISPERS = [
  "a door you forgot about is being unlocked from the other side.",
  "the question you avoided in 2022 is asking again. softer this time.",
  "someone dreamt about you last night and didn't tell you.",
  "the {month} you're waiting for is closer than the calendar admits.",
  "what you want is not late. you are exactly on time.",
  "there is a yes with your name on it, waiting for you to be brave.",
  "your future self is not disappointed. they are rooting for you.",
  "the thing you keep almost doing — do it this week, {name}.",
  "you are allowed to change the rules you set before you knew yourself.",
  "a quiet revolution is happening in how you see yourself. keep going.",
  "the ancestor who would be proud of you right now — picture their face.",
  "someone who rejected you is about to reach out. you do not have to answer.",
  "the creative thing you've been rehearsing in your head — begin it small, today.",
  "the river does not apologize for where it goes. neither do you, {name}.",
];
function randomWhisper(user){
  return fillTemplate(WHISPERS[Math.floor(Math.random()*WHISPERS.length)], user);
}

// Compatibility scoring — deterministic, playful
function compatScore(a, b){
  if (!a || !b) return 0;
  const s = hashStr((a.name||"") + (a.dob||"") + "|" + (b.name||"") + (b.dob||""));
  // Map into a curve that feels good — mostly 60-95
  return 50 + (s % 46);
}
function compatReading(a, b, score, user){
  const sigil = ["❤","💫","🜂","♾","🕯","🗝","🌙","🔱"][hashStr((a?.name||"")+(b?.name||""))%8];
  const readings = [
    "your bond is an ember the world has tried and failed to extinguish.",
    "you met each other mid-sentence. the rest of the sentence is still being written.",
    "this is not a coincidence. the universe has been engineering this alignment for longer than you've been alive.",
    "you teach each other the thing you each came here to learn. that is the definition.",
    "this relationship is a mirror held at an unusual angle. what it shows is true.",
    "you balance each other's missing frequencies. this is rarer than either of you realizes.",
    "the chemistry is not the question. the question is whether you will both be brave.",
    "you've already met in dreams, {name}. the waking version is catching up.",
  ];
  const label =
    score >= 92 ? "destined" :
    score >= 82 ? "magnetic" :
    score >= 70 ? "aligned" :
    score >= 58 ? "complicated" :
                  "cautionary";
  const body = fillTemplate(readings[hashStr(a?.name + b?.name)%readings.length], user);
  return { sigil, label, body };
}
