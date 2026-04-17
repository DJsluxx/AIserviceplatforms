// Procedural idea generation dataset
// Dimensions combine to produce 100,000+ unique business ideas

const NICHES = [
  { name: "fitness", emoji: "💪", market: 96, growth: 7.2, keywords: ["workout", "trainer", "recovery", "strength", "cardio"] },
  { name: "pets", emoji: "🐾", market: 261, growth: 6.1, keywords: ["pet care", "dog", "cat", "pet parent", "training"] },
  { name: "parenting", emoji: "👶", market: 320, growth: 4.8, keywords: ["kids", "toddler", "baby", "mom", "dad"] },
  { name: "mental health", emoji: "🧠", market: 240, growth: 12.4, keywords: ["therapy", "anxiety", "mindfulness", "journaling", "meditation"] },
  { name: "creator economy", emoji: "🎬", market: 104, growth: 22.5, keywords: ["creator", "content", "streamer", "youtuber", "tiktoker"] },
  { name: "remote work", emoji: "🏠", market: 87, growth: 15.1, keywords: ["WFH", "async", "distributed team", "digital nomad", "hybrid"] },
  { name: "personal finance", emoji: "💰", market: 210, growth: 9.3, keywords: ["budget", "invest", "debt-free", "credit", "savings"] },
  { name: "crypto & web3", emoji: "⛓️", market: 78, growth: 18.4, keywords: ["DeFi", "NFT", "DAO", "on-chain", "token"] },
  { name: "sustainability", emoji: "🌱", market: 145, growth: 14.2, keywords: ["eco", "zero-waste", "carbon", "upcycle", "regenerative"] },
  { name: "food & cooking", emoji: "🍳", market: 410, growth: 5.6, keywords: ["recipe", "meal", "chef", "kitchen", "ingredient"] },
  { name: "travel", emoji: "✈️", market: 385, growth: 8.8, keywords: ["adventure", "itinerary", "local", "wanderlust", "explore"] },
  { name: "beauty & skincare", emoji: "✨", market: 180, growth: 8.1, keywords: ["glow", "routine", "ingredient", "clean beauty", "derm"] },
  { name: "gaming", emoji: "🎮", market: 197, growth: 11.7, keywords: ["gamer", "streamer", "esports", "guild", "loot"] },
  { name: "aging & longevity", emoji: "⏳", market: 156, growth: 13.9, keywords: ["biohack", "longevity", "senior", "healthspan", "NAD+"] },
  { name: "productivity", emoji: "⚡", market: 62, growth: 10.3, keywords: ["focus", "deep work", "habits", "GTD", "time-block"] },
  { name: "home & DIY", emoji: "🔨", market: 510, growth: 4.2, keywords: ["renovate", "decor", "smart home", "organize", "declutter"] },
  { name: "education & learning", emoji: "📚", market: 340, growth: 9.9, keywords: ["course", "tutor", "skill", "bootcamp", "cohort"] },
  { name: "dating & relationships", emoji: "💕", market: 48, growth: 6.4, keywords: ["match", "couples", "single", "coach", "intimacy"] },
  { name: "career & side hustles", emoji: "💼", market: 130, growth: 11.2, keywords: ["freelance", "resume", "interview", "income", "hustle"] },
  { name: "real estate", emoji: "🏡", market: 620, growth: 5.3, keywords: ["landlord", "tenant", "rental", "property", "STR"] },
  { name: "auto & EV", emoji: "🚗", market: 440, growth: 7.8, keywords: ["driver", "EV", "charging", "mechanic", "commute"] },
  { name: "neurodivergent support", emoji: "🧩", market: 52, growth: 16.7, keywords: ["ADHD", "autism", "dyslexia", "sensory", "executive function"] },
  { name: "micro-farming", emoji: "🌾", market: 38, growth: 13.1, keywords: ["urban farm", "hydroponic", "homestead", "permaculture", "backyard"] },
  { name: "spirituality & rituals", emoji: "🔮", market: 67, growth: 8.9, keywords: ["astrology", "tarot", "ritual", "manifesting", "energy"] },
  { name: "craft & handmade", emoji: "🧶", market: 49, growth: 7.4, keywords: ["artisan", "handmade", "maker", "craft", "print-on-demand"] },
  { name: "b2b SaaS", emoji: "💻", market: 720, growth: 14.8, keywords: ["ops", "team", "workflow", "dashboard", "automation"] },
  { name: "legal & compliance", emoji: "⚖️", market: 270, growth: 6.9, keywords: ["contract", "paralegal", "GDPR", "LLC", "privacy"] },
  { name: "senior living", emoji: "👴", market: 195, growth: 10.5, keywords: ["senior", "caregiver", "aging in place", "assisted", "dementia"] },
  { name: "language learning", emoji: "🗣️", market: 60, growth: 9.1, keywords: ["fluent", "immersion", "pronunciation", "bilingual", "polyglot"] },
  { name: "audio & podcasting", emoji: "🎧", market: 35, growth: 15.6, keywords: ["podcast", "audio", "voice", "radio", "host"] },
  { name: "fashion & resale", emoji: "👗", market: 390, growth: 6.8, keywords: ["thrift", "resale", "outfit", "capsule", "vintage"] },
  { name: "writers & authors", emoji: "✍️", market: 42, growth: 8.7, keywords: ["novel", "author", "self-publish", "newsletter", "prose"] },
  { name: "social anxiety & introverts", emoji: "🫥", market: 28, growth: 12.2, keywords: ["introvert", "quiet", "social", "anxiety", "solo"] },
  { name: "climate tech", emoji: "🌍", market: 205, growth: 19.3, keywords: ["carbon", "offset", "climate", "emissions", "green"] },
];

const MODELS = [
  { name: "SaaS subscription", emoji: "☁️", startup: 15000, margin: 82, scale: 9 },
  { name: "marketplace", emoji: "🛒", startup: 28000, margin: 18, scale: 10 },
  { name: "subscription box", emoji: "📦", startup: 9000, margin: 42, scale: 7 },
  { name: "online course", emoji: "🎓", startup: 1500, margin: 88, scale: 6 },
  { name: "paid community", emoji: "👥", startup: 800, margin: 90, scale: 5 },
  { name: "newsletter (paid)", emoji: "📰", startup: 300, margin: 92, scale: 5 },
  { name: "mobile app", emoji: "📱", startup: 12000, margin: 75, scale: 9 },
  { name: "physical product (DTC)", emoji: "📦", startup: 18000, margin: 38, scale: 8 },
  { name: "AI agent service", emoji: "🤖", startup: 2000, margin: 78, scale: 9 },
  { name: "done-for-you agency", emoji: "🛠️", startup: 500, margin: 55, scale: 4 },
  { name: "affiliate media site", emoji: "🔗", startup: 200, margin: 85, scale: 6 },
  { name: "physical rental", emoji: "🔑", startup: 7500, margin: 48, scale: 6 },
  { name: "local service", emoji: "📍", startup: 2500, margin: 52, scale: 3 },
  { name: "data/API product", emoji: "🔌", startup: 6000, margin: 86, scale: 8 },
  { name: "browser extension", emoji: "🧩", startup: 800, margin: 94, scale: 7 },
  { name: "print-on-demand", emoji: "🖨️", startup: 100, margin: 25, scale: 5 },
  { name: "freemium tool", emoji: "🆓", startup: 3500, margin: 80, scale: 8 },
  { name: "digital template shop", emoji: "📐", startup: 150, margin: 95, scale: 5 },
  { name: "franchise kit", emoji: "🏪", startup: 45000, margin: 22, scale: 9 },
  { name: "productized consulting", emoji: "🎯", startup: 400, margin: 72, scale: 4 },
];

const AUDIENCES = [
  "Gen Z creators", "millennial parents", "digital nomads", "SMB owners",
  "side-hustle dads", "overwhelmed moms", "Gen X retirees", "freshly divorced",
  "first-time buyers", "recent grads", "burned-out professionals", "hybrid workers",
  "indie hackers", "bootstrappers", "HENRYs (high earners not rich yet)",
  "DINK couples", "solopreneurs", "empty nesters", "immigrants in the US",
  "expats in Europe", "neurodivergent adults", "single moms", "single dads",
  "college athletes", "weekend warriors", "hobby collectors", "serial plant killers",
  "reformed doomscrollers", "casual crypto curious", "AI-skeptical professionals",
];

const ANGLES = [
  { name: "AI-first", weight: 1.3, emoji: "🤖" },
  { name: "hyperlocal", weight: 1.1, emoji: "📍" },
  { name: "gamified", weight: 1.15, emoji: "🎮" },
  { name: "community-led", weight: 1.2, emoji: "🤝" },
  { name: "invite-only", weight: 1.1, emoji: "🔐" },
  { name: "voice-first", weight: 1.15, emoji: "🎙️" },
  { name: "offline-first", weight: 1.0, emoji: "📴" },
  { name: "anti-algorithm", weight: 1.2, emoji: "🚫" },
  { name: "radically transparent", weight: 1.1, emoji: "🔍" },
  { name: "bundled with hardware", weight: 1.25, emoji: "🔧" },
  { name: "on-chain verified", weight: 1.1, emoji: "⛓️" },
  { name: "creator-owned", weight: 1.15, emoji: "👑" },
  { name: "ethically sourced", weight: 1.05, emoji: "🌿" },
  { name: "async-only", weight: 1.1, emoji: "⏱️" },
  { name: "no-app", weight: 1.0, emoji: "📵" },
  { name: "text-message-native", weight: 1.1, emoji: "💬" },
  { name: "wearable-integrated", weight: 1.2, emoji: "⌚" },
  { name: "privacy-first", weight: 1.15, emoji: "🛡️" },
];

const HOOKS = [
  "that remembers context across every interaction",
  "that replaces a $300/hr specialist with a $29/month tool",
  "that turns a 6-hour chore into a 5-minute ritual",
  "where your progress is owned by you, not the platform",
  "built for the 2am version of yourself",
  "that works even when your internet doesn't",
  "that pays you to use it consistently",
  "that ships a physical surprise to your door",
  "designed to be deleted when you've outgrown it",
  "that replaces 4 different apps with 1 clear flow",
  "priced so the right people can afford it, wrong people can't",
  "with a money-back guarantee tied to your results",
  "that onboards in under 30 seconds with zero friction",
  "built by operators, not by VCs",
  "where revenue is split 50/50 with creators",
  "with transparent unit economics shown to every user",
  "backed by a dataset no competitor has",
];

const NAME_PREFIXES = ["Luma","Nova","Echo","Kite","Pulse","Atlas","Orbit","Bloom","Ember","Lumen",
  "Drift","Quill","Nimbus","Terra","Vault","Forge","Haven","Beacon","Prism","Cinder",
  "Rhythm","Glow","Axiom","Lattice","Mural","Stack","Bolt","Rook","Mosaic","Juno",
  "Ripple","Compass","Tangent","Arc","Pioneer","Fable","Clover","Sable","Yonder","Rally"];
const NAME_SUFFIXES = ["HQ","Lab","Club","OS","AI","Works","Co","Studio","Guild","Path",
  "Forge","Loop","Kit","Deck","Scope","Core","Flow","Base","Signal","Nest",
  "Script","Pilot","Layer","Press","Bureau","Canvas","Field","Mint","Seed","Grid"];

function rand(arr){return arr[Math.floor(Math.random()*arr.length)];}
function randInt(min,max){return Math.floor(Math.random()*(max-min+1))+min;}

function genName(niche){
  const a = rand(NAME_PREFIXES);
  const b = rand(NAME_SUFFIXES);
  const style = Math.random();
  if (style < 0.4) return `${a}${b}`;
  if (style < 0.7) return `${a} ${b}`;
  const kw = rand(niche.keywords);
  const cap = kw.charAt(0).toUpperCase()+kw.slice(1);
  return `${cap}${b}`;
}

function generateIdea(seed){
  const niche = rand(NICHES);
  const model = rand(MODELS);
  const audience = rand(AUDIENCES);
  const angle = rand(ANGLES);
  const hook = rand(HOOKS);
  const name = genName(niche);

  // Financial math
  const market = niche.market;
  const growth = niche.growth;
  const startupCost = Math.round(model.startup * (0.7 + Math.random() * 0.6));
  const margin = Math.min(96, Math.round(model.margin * (0.85 + Math.random() * 0.3)));

  // Revenue projection model
  const priceBase = model.name.includes("subscription") || model.name.includes("SaaS") || model.name.includes("community") ? randInt(12,89)
    : model.name.includes("course") ? randInt(97,997)
    : model.name.includes("agency") || model.name.includes("consulting") ? randInt(500,5000)
    : randInt(9,199);

  const reach = Math.round((market * 1e9 * 0.0001 * angle.weight) / priceBase);
  const year1Customers = Math.max(50, Math.round(reach * (0.002 + Math.random()*0.008)));
  const year1Revenue = year1Customers * priceBase * (model.name.includes("subscription")||model.name.includes("SaaS")||model.name.includes("community")||model.name.includes("newsletter") ? 12 : 1);
  const year3Revenue = Math.round(year1Revenue * (3 + Math.random() * 4));

  // Scores
  const difficulty = Math.min(10, Math.max(1, Math.round(model.scale * 0.7 + (startupCost > 10000 ? 3 : 0) + Math.random()*2 - 1)));
  const potential = Math.min(10, Math.max(1, Math.round((growth/2) + model.scale*0.3 + angle.weight*2 + Math.random()*1.5)));
  const uniqueness = Math.min(10, Math.max(3, Math.round(angle.weight*4 + Math.random()*4)));
  const speed = Math.min(10, Math.max(1, Math.round(11 - model.scale*0.6 - (startupCost/5000) + Math.random()*2)));

  // Rarity tier (tuned to p25/p50/p75/p95 of distribution)
  const score = potential*2 + uniqueness + (growth/2);
  let tier = "common", tierEmoji = "🟢";
  if (score >= 37) { tier = "legendary"; tierEmoji = "🌟"; }
  else if (score >= 34) { tier = "epic"; tierEmoji = "🟣"; }
  else if (score >= 31) { tier = "rare"; tierEmoji = "🔵"; }
  else if (score >= 27) { tier = "uncommon"; tierEmoji = "🟡"; }

  const tagline = `A ${angle.name} ${model.name} for ${audience} in the ${niche.name} space, ${hook}.`;

  const actionPlan = buildActionPlan(model, niche, angle);
  const skills = buildSkills(model, angle);
  const risks = buildRisks(model, niche);
  const moats = buildMoats(angle, model);

  return {
    id: (seed || Date.now()) + "_" + Math.random().toString(36).slice(2,8),
    name, tagline,
    niche, model, audience, angle,
    emoji: niche.emoji,
    price: priceBase,
    startupCost, margin,
    year1Revenue, year3Revenue,
    difficulty, potential, uniqueness, speed,
    tier, tierEmoji,
    marketSize: market,
    growthRate: growth,
    actionPlan, skills, risks, moats,
    score: Math.round(score*10)/10,
  };
}

function buildActionPlan(model, niche, angle){
  const steps = [];
  steps.push(`Interview 15 ${niche.keywords[0]} obsessives and document their top 3 frustrations.`);
  steps.push(`Write the landing page first — sell before you build. Target ${Math.round(300 + Math.random()*700)} waitlist signups.`);
  if (model.name.includes("SaaS") || model.name.includes("app") || model.name.includes("extension") || model.name.includes("AI")) {
    steps.push(`Ship a no-code MVP in 14 days (Lovable / v0 / Bubble) with one killer feature only.`);
  } else if (model.name.includes("course") || model.name.includes("community") || model.name.includes("newsletter")) {
    steps.push(`Run a $1 beta cohort for 20 people, record everything, harvest testimonials.`);
  } else if (model.name.includes("product") || model.name.includes("box")) {
    steps.push(`Source a small batch (50-100 units) via Alibaba/local supplier, validate unit economics.`);
  } else {
    steps.push(`Deliver 10 manually-built engagements to pressure-test the offer before automating.`);
  }
  steps.push(`Price at $${Math.round(9 + Math.random()*40)}/mo or $${Math.round(99 + Math.random()*400)} one-time — test both in parallel.`);
  steps.push(`Build distribution on ${rand(["TikTok","X","LinkedIn","Reddit","YouTube Shorts","a niche newsletter"])} — post 5x/week for 60 days.`);
  steps.push(`Layer in ${angle.name} as the differentiator once you have 100 paying users.`);
  steps.push(`At $10k MRR: hire a VA, document SOPs, double down on the channel that worked.`);
  return steps;
}

function buildSkills(model, angle){
  const all = [];
  if (model.name.includes("SaaS") || model.name.includes("app") || model.name.includes("AI") || model.name.includes("extension")) {
    all.push("product thinking","basic coding or no-code chops","UX instinct");
  }
  if (model.name.includes("course") || model.name.includes("community") || model.name.includes("newsletter")) {
    all.push("writing","on-camera confidence","teaching");
  }
  if (model.name.includes("agency") || model.name.includes("consulting") || model.name.includes("service")) {
    all.push("sales calls","scoping & pricing","project mgmt");
  }
  all.push("distribution","customer empathy","shipping fast");
  if (angle.name === "AI-first") all.push("prompt engineering");
  if (angle.name === "on-chain verified") all.push("smart contract basics");
  return [...new Set(all)].slice(0, 5);
}

function buildRisks(model, niche){
  const risks = [];
  if (model.margin < 40) risks.push("Thin margins — one bad month can sink cash flow.");
  if (niche.growth < 6) risks.push("Slower-growing market — harder to ride a tailwind.");
  if (model.scale > 8) risks.push("Large incumbents may replicate if you validate the wedge.");
  if (model.name.includes("marketplace")) risks.push("Cold-start problem: both sides must be courted simultaneously.");
  if (model.name.includes("crypto") || model.name.includes("on-chain")) risks.push("Regulatory ambiguity in key markets.");
  if (model.startup > 20000) risks.push("High startup cost gates the experiment.");
  risks.push("Distribution is the real moat — if you can't reach the audience, nothing else matters.");
  return risks.slice(0,4);
}

function buildMoats(angle, model){
  const moats = [];
  if (angle.name === "community-led") moats.push("Network effects of an engaged community");
  if (angle.name === "AI-first") moats.push("Proprietary prompts, fine-tunes, and user data flywheel");
  if (angle.name === "hyperlocal") moats.push("Geographic density is hard to replicate fast");
  if (angle.name === "bundled with hardware") moats.push("Hardware BOM + shipping barrier keeps copycats out");
  if (model.margin > 80) moats.push("Fat margins fund CAC while competitors bleed cash");
  if (model.name.includes("data") || model.name.includes("API")) moats.push("Accumulated dataset compounds monthly");
  moats.push("Brand trust earned in a specific niche is almost impossible to spoof");
  return moats.slice(0,3);
}
