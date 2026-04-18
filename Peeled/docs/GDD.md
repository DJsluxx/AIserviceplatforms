# PEELED — Game Design Document

**Version:** 1.0 · **Author:** Claude (for Daniel) · **Last updated:** 2026-04-18

---

## 1. Concept in One Paragraph

**PEELED** is a live, always-on, single-world mobile game. Mysterious virtual packages — each with a hidden number of layers — travel between players across the planet. When a package arrives, a push notification pings you: you have a limited time window to peel **one** layer. Each layer reveals a clue, fact, joke, or mini-reward. When the **final** layer is peeled, the lucky peeler wins the entire package — a rare reward worth flexing. Miss your window, and the package gets passed to someone else somewhere else in the world. A live, mesmerising globe shows packages zipping between cities in real time.

It is one part *hot potato*, one part *advent calendar*, one part *BeReal notification anxiety*, one part *Pokemon GO global event*. It is designed to be shared, screenshotted, and TikTok'd.

---

## 2. Design Pillars

All decisions must serve at least one pillar. If a feature serves none — cut it.

1. **Tactile Delight.** Peeling must feel physically satisfying — perfect haptics, sound, particle work. The moment of peel is the moment we keep the user.
2. **Global Presence.** The player must feel connected to real humans worldwide. The globe, the sender names, the city tags — all reinforce this.
3. **Rare & Precious.** Receiving a package is rare. Winning one is rarer. Scarcity is the emotion we sell.
4. **Screenshot-First.** Every core moment (receive, final peel, win) must produce a share-ready visual. No win is ever private unless the user opts out.
5. **Kind by Default.** No grief mechanics. No PvP aggression. Friends can target each other only positively. PEELED is warm.
6. **Respect Attention.** We interrupt the user only when a real package needs them. Never spam.

---

## 3. Core Gameplay Loop

```
[Install] → [Onboard: choose avatar + tap globe] → [Get first "welcome package"]
    ↓
[Peel first layer — win tiny reward, see map]
    ↓
[Invite friends OR wait to be targeted]
    ↓
[Receive notification: "A package is coming! 38s to open"]
    ↓
[Peel one layer → reward OR "just a hint" OR final layer]
    ↓
   [If final layer] → BIG WIN screen → share card → leaderboard bump
   [If not final]   → Choose: PASS IT (send onward) OR HOLD (keep 10s then auto-pass)
    ↓
[Return to globe, watch packages, collect streak, back to top]
```

**Session length target:** 90 seconds typical, 10 minutes on a "package-heavy" day.

---

## 4. Key Entities

### 4.1 Package

| Attribute | Notes |
|---|---|
| `id` | UUID |
| `rarity` | `common | uncommon | rare | epic | legendary | mythic` |
| `theme` | Seasonal theme (e.g. `spring_garden`, `cosmic`, `arcade`) |
| `total_layers` | 3–12, hidden from users until final peel |
| `peels_remaining` | Derived; shown as fuzzy "a few left" hints after layer 3 |
| `prize_id` | What's inside the final layer |
| `origin_user_id` | Who started it (gets referral credit on final open) |
| `current_holder_id` | Who holds it now |
| `current_holder_deadline` | When this user's window expires |
| `travel_path` | List of (user_id, city, lat, lng, at) hops |
| `created_at` | |
| `status` | `in_flight | completed | abandoned | expired_to_void` |

### 4.2 Layer

Each layer is one of:

- **Hint** — a clue about the prize (no value, builds tension)
- **Mini-reward** — small coins (10–50), cosmetic sticker, XP
- **Power-up** — `Peek` (1 hint on future package), `Slowdown` (extra 10s on future), `Double-dip` (peel 2 at once)
- **Trap** *(rare, only in Mythic packages)* — costs you the package (you pass immediately, lose nothing but the package)
- **Final** — the Prize layer (reveals big reward + win screen)

Layer composition is weighted by rarity — see [server/app/services/layer_engine.py](../server/app/services/layer_engine.py).

### 4.3 Prize (Final Layer Reward)

| Rarity | Prize Type |
|---|---|
| Common | 100–300 coins + bronze sticker |
| Uncommon | 300–700 coins + silver sticker |
| Rare | 700–2,000 coins + avatar frame |
| Epic | 2,000–5,000 coins + rare avatar + "city pin" on globe forever |
| Legendary | 10,000 coins + custom title + 7-day globe "halo" effect |
| Mythic | Real-world reward (gift card, merch, limited edition NFT-style badge) — 1% chance contains a sponsor prize |

### 4.4 Player

```
player {
  id, username, avatar, country, city_hint (coarse, not exact),
  xp, level, coins, streak_days, stickers[], frames[], powerups{},
  reputation_score (0-100, affects matchmaking),
  friends[], blocked_users[],
  notification_prefs, privacy_prefs
}
```

---

## 5. The Peel Mechanic — The Sacred Moment

This is where we win or lose the user. Design spec:

1. **Pre-peel:** A wrapped package pulses on screen. Timer bar ticks down. Ambient whoosh sound.
2. **Tap & hold:** User presses and holds. A subtle "tug" haptic fires every 100ms. Tape begins peeling with elastic physics.
3. **Release:** If held >600ms, the layer tears off with a confetti burst scaled by rarity. Device haptic "pop".
4. **Reveal:** Layer content animates in (3D card flip with Rive animation).
5. **Action bar:** Two giant buttons — `PASS FORWARD →` (random) or `SEND TO FRIEND ↗`. Plus a subtle `HOLD 10s` hourglass for deliberation.

Animation lib: **Rive** for the wrapper unwrap. **flutter_animate** for confetti, shakes, glows.

Sounds: Bespoke package unwrap foley (crinkle → tape rip → pop), ambient globe hum, short stingers for rarity tiers.

---

## 6. Package Routing — The Economy's Engine

### 6.1 Principles

- **Authoritative:** The server picks the next recipient. Clients never negotiate.
- **Generic N-package:** The router does not know or care how many packages are live. Each package is an independent state machine.
- **Fair-but-fun:** Weighted by (a) currently online, (b) recent activity, (c) "deservedness" (low recent-receives), (d) friend affinity if sender chose SEND_TO_FRIEND, (e) geography (prefer nearby cities for shorter visual hops).
- **Anti-dead-end:** If a chosen recipient doesn't open within window, package re-routes instantly. Every 5 failed hops, rarity downgrades one tier (prevents infinite travel).
- **Void sink:** After 50 total hops with no full open, package "returns to the void" and is abandoned. (Stats logged for balancing.)

### 6.2 Data flow

```
[send_package API]
   → validates signed-action token
   → picks next recipient via RecipientPicker
   → writes package_event (sent)
   → enqueues expiration timer to Redis (ZSET by deadline)
   → broadcasts map event to "live_map" Realtime channel
   → triggers FCM push to recipient
```

The `package_ticker` worker polls Redis for expired timers every 500ms and re-routes.

### 6.3 Recipient weights

```
weight(user) = w_online    * is_online(user)
             + w_activity  * recent_activity_score(user)
             + w_fairness  * (1 / (1 + receives_last_6h(user)))
             + w_friend    * is_target_friend(user)      # only if SEND_TO_FRIEND
             + w_geo       * proximity_bonus(user, sender_city)
             + w_streak    * streak_bonus(user)
```

Weights live in [server/app/services/package_router.py](../server/app/services/package_router.py) — all tunable via `config.yaml`.

---

## 7. The Live Globe

- 3D globe projection (Mapbox globe style).
- Dots pulse at cities with active players (privacy: city, not exact coord).
- Arc lines animate packages mid-flight (client-side ease-out curves).
- Tap an arc → see package rarity + layers-peeled-so-far (no spoilers).
- Tap a city → see how many players are online, how many packages recently touched it.
- **"Halo" effect** — recent legendary winners get a golden halo on their city for 7 days.
- Low-power devices get a 2D fallback (fewer particle effects).

---

## 8. Social & Virality

### 8.1 Invite / Send-to-Friend

- Sending to a friend **guarantees** they are the next hop (but their peel window is 20% shorter to prevent abuse).
- Sending to a stranger is the default — random weighted pick.
- New users sent via invite link join the sender's "clan" — bonus coins when their clan wins legendary packages.

### 8.2 Share cards

- Every final peel auto-generates a shareable card with the prize, city, time, streak, and a cinematic GIF of the peel.
- Cards open a deep link that lets the viewer instantly join + receive their first package.
- Default privacy: public share. User can set shares to friends-only.

### 8.3 The Chase

Legendary and Mythic packages are named, tracked, and globally visible:
> *"Golden Parcel #73 is in Mumbai with 2 layers left. Last peeled by @ravi_22 - 38s ago."*

Users can subscribe to chase a legendary package — they get a push if it lands near them. Turns the globe into live theater.

### 8.4 Leaderboards

- **Global:** Most packages opened (weekly reset).
- **Country:** Same, filtered.
- **Friends:** Among your friends.
- **Speed:** Fastest peel on same rarity tier.
- **Streaks:** Longest daily-login streak.

Uses Redis ZSETs keyed by leaderboard type.

### 8.5 Clans (post-launch)

Groups of 20 users. Clan missions (collectively peel N packages this week) for shared rewards. Chat limited to pre-built emote cards (no open chat — reduces moderation cost + toxicity).

---

## 9. Progression & Retention

### 9.1 Daily loop hooks

- **Daily PEELED**: Every 24h, a guaranteed package lands in your inbox (common/uncommon). Keeps streak alive.
- **Streak multiplier**: Days 1, 3, 7, 14, 30, 60, 100 unlock cosmetic rewards. Streak freeze token (earnable) forgives one missed day.
- **Seasonal theme**: Every 6 weeks a new visual theme refreshes package art, layer types, seasonal prizes.
- **Featured package**: Once per day the app promotes a single legendary package in-flight — tap to "subscribe to its chase."

### 9.2 XP & Level

- Peel any layer = +5 XP
- Final peel = +50 XP × rarity multiplier
- Pass-to-friend = +2 XP (social reward)
- Invite-install = +100 XP
- Level gates unlock: extended peel windows (+5s at L10, +10s at L25), power-up inventory slots, premium avatar frames.

### 9.3 Cosmetics

- Avatar frames, city pins, peel-confetti variants, "signed by" tag on passed packages.
- Bought with coins (earned) or PEELED Tokens (premium, see §10).

---

## 10. Monetization

Principle: **never lock the core loop behind payment.** Everything paid is cosmetic, convenience, or extra chances — not gameplay advantage.

### 10.1 Revenue streams

1. **PEELED Plus** ($4.99/mo) — Premium subscription:
   - 2× extra peel window on all packages (20s → 40s)
   - 5 free "Peek" power-ups per week
   - Exclusive seasonal frame + pin
   - No ads (ads exist only on non-Plus users, tastefully, between sessions — never mid-peel)
   - Priority on "Daily PEELED"

2. **PEELED Tokens** (IAP) — Hard currency:
   - $0.99 → 100 tokens; $4.99 → 600; $19.99 → 3,000; $49.99 → 9,000
   - Spend on: power-ups, cosmetics, streak freezes, "send-to-friend" extra slots

3. **Sponsored Mythic packages** — Brands sponsor real-world prizes (gift cards, merch). The brand gets a tasteful logo on the package wrapper + the winner's share card. *Only 1 in 1000 legendary packages may be sponsored.*

4. **Rewarded ads** (opt-in) — Watch an ad to earn an extra peel window, +1 token, or a streak freeze. Never served without user action.

### 10.2 What we will NOT do

- No energy/stamina paywalls.
- No pay-to-win (paid users cannot get better prizes than free users, only more cosmetic flex).
- No loot box with paid-only content — every cosmetic is earnable.
- No dark patterns on unsubscribe — one-tap cancel, honored immediately.

### 10.3 Price anchors

Target LTV:CAC ≥ 3:1 at 90 days post-install. Break-even CAC budget: $1.80 for a 2% paying-user ratio at $45 avg annual spend.

---

## 11. Notifications

The single most important retention lever. Also the single easiest way to destroy trust.

### 11.1 Categories (user toggleable)

1. **Package Arriving** — a real package has landed in your inbox. HIGH PRIORITY. Max 6/day hard cap.
2. **Legendary Chase** — a legendary you subscribed to is near. MED PRIORITY.
3. **Friend Activity** — friend won a package / sent you one. LOW PRIORITY, bundled daily at 7pm local.
4. **Streak Reminder** — "Your streak ends in 2h!" — once per day max, only if in-danger.
5. **Seasonal Launch** — new theme drop. Rate limited to 1/week.

### 11.2 Rules

- Respect quiet hours (00:00–07:00 local time) unless PEELED Plus user opts in.
- Collapse duplicate notifications within 30min.
- Dead Man's Switch: if user hasn't opened the app in 7 days, reduce to max 1 notif/day. 14 days → 1/week. 30 days → one final "we miss you" with a free legendary, then silent.

Full logic in [server/app/services/notification.py](../server/app/services/notification.py).

---

## 12. Anti-Cheat

### 12.1 Threats

- Emulators/automation running headless clients to hoard peels
- Multi-account farming (one human, 50 accounts)
- Replay attacks (capture a peel payload, replay it)
- Clock spoofing (client claims peel happened within window when it didn't)

### 12.2 Defences

1. **Server clock is authoritative.** Client timestamps are advisory only.
2. **Action signing.** Every gameplay action is signed server-side when issued (nonce + expiry + action type + package_id). Server rejects any reused nonce.
3. **Device integrity:** Play Integrity API (Android) + DeviceCheck/App Attest (iOS) on sensitive actions.
4. **Behavioral heuristics:** Impossibly-fast peels, peels from rotating IPs, packages only sent to same 3 accounts, flag to shadow-bucket.
5. **Shadow banning:** Suspected cheaters continue playing in an isolated instance — they see packages but never receive real prizes. No feedback signal for the cheater.
6. **Rate limits:** Per-user, per-IP, per-device. Enforced in Redis.

Details in [server/app/services/anti_cheat.py](../server/app/services/anti_cheat.py).

---

## 13. Scalability

### 13.1 Targets

- 100k DAU at launch soft-cap
- 1M DAU scale ceiling for v1
- P99 peel-to-confirm latency < 250ms globally
- Notification fanout < 2s for 100k concurrent online users

### 13.2 Strategies

- Cloud Run auto-scales FastAPI instances per region
- Supabase read replicas per region (post-launch)
- Redis cluster for leaderboards and in-flight state
- Package events are append-only — perfect for eventual-consistency reads
- Live map channel uses Supabase Realtime broadcast, not per-user channels
- FCM topic subscriptions for "chase" notifications (not per-device loops)
- Static assets on Cloudflare CDN

### 13.3 Cost ceiling

Target unit cost < $0.002/DAU. Monitor via Grafana dashboards and alert when drifting.

---

## 14. Accessibility

- VoiceOver / TalkBack labels on every interactive element
- Colorblind-friendly rarity palette (shape + color, not color alone)
- Text sizing respects OS setting
- All peel animations have a "reduce motion" alternative
- Haptics toggleable for sensory sensitivity
- Game works one-handed

---

## 15. Moderation & Safety

- No open text chat. Pre-built emote cards only.
- Usernames filtered against profanity lists at registration.
- Minors (<13): no location-based matching, no sponsored packages, display-name is avatar ID only.
- Report button on every user profile and package card.
- Automated review for reports + human queue.

---

## 16. Seasonal Events

Every 6 weeks a theme rolls out. Examples in backlog:

| Season | Theme | Unique Mechanic |
|---|---|---|
| S1 | **Cosmic Cardboard** | Packages orbit the earth; rare asteroid packages from space |
| S2 | **Paper Lanterns** | Evening launch events — packages light up at dusk per timezone |
| S3 | **Holiday Ribbon** | Every package has a gift-tag; name-your-recipient wraps it for a friend |
| S4 | **Cherry Bloom** | Packages drift on wind; players vote on where wind blows |
| S5 | **Neon Rush** | Faster timers, double layers, electronic soundtrack |
| S6 | **Time Capsule** | Packages can be "buried" to open 1 week later |

Season calendar in [server/app/services/seasonal.py](../server/app/services/seasonal.py).

---

## 17. Metrics We Watch

| Metric | Target | Why |
|---|---|---|
| D1 retention | 45% | Confirms onboard magic |
| D7 retention | 20% | Confirms loop hooks |
| D30 retention | 10% | Confirms long game |
| Packages opened/DAU/day | 1.5 | Supply sanity |
| Avg layers peeled/session | 2.0 | Engagement depth |
| Share rate / final peel | 15% | Virality check |
| K-factor | 0.4+ (target 1.0) | Organic growth |
| Paying user % | 2% | Monetization floor |
| P99 peel latency | < 250ms | UX quality |
| Crash-free sessions | 99.8% | Stability floor |

---

## 18. Above-and-Beyond Features (Post-MVP)

Ambitious additions to consider once core loop proves:

1. **Voice Notes on Packages** — the sender records a 3-second voice note for the final opener. "Hi from Sydney!"
2. **PEELED Live** — once per month, a globally synchronised event where everyone online gets the same package in waves across 15 minutes. Watch the globe go crazy.
3. **AR Peel** — point your camera, a real-world package appears on your table for peeling (ARKit/ARCore).
4. **PEELED Maker** — creators can design their own package themes, submit for review, earn royalties on each use.
5. **Collectable Journey** — replay your package's 20-city travel history as a 15s cinematic suitable for TikTok.
6. **Physics-based peel** — each peel is a mini tug-of-war, rotation + force combine. Adds skill.
7. **Cross-platform watch widget** — Apple Watch / Wear OS complication pulses when a package arrives.
8. **Passive-Globe-Mode** — lock-screen widget that streams the globe as ambient decoration.
9. **"Inherit"** — when a package has been in-flight 24h+ with no open, it goes into "Inheritance" mode — the next opener who successfully peels wins all accumulated layers at once. Huge dopamine.
10. **Charity Mythics** — monthly Mythic with no cash prize but a donation in the winner's name. Opt-in, beautiful cause marketing.

---

## 19. MVP Cut Line (what ships in v1.0)

**In:**
- Onboarding + auth
- Core peel loop (receive → peel → pass / keep)
- 6 rarities + basic layer types
- Live Globe (basic)
- Leaderboards (global + friends)
- Daily PEELED streak
- Friends + send-to-friend
- Share cards
- FCM push
- PEELED Plus subscription + IAP tokens
- Rewarded ads (optional)
- Basic anti-cheat
- Safety: report + block
- 1 seasonal theme ("Launch")

**Out (post-launch):**
- Clans
- Voice notes
- AR Peel
- PEELED Live events
- PEELED Maker
- Sponsored packages
- "Inherit" mode

---

## 20. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Cold-start — not enough packages in flight at launch | Seed 2,000 bot-sent packages/day in region 1 during soft-launch. Gradually reduce. |
| Notification fatigue | Hard caps + Dead Man's Switch + explicit per-category toggles |
| Cheating ecosystem forms | Shadow banning + device integrity + progressive detection sophistication |
| Regulatory (loot-box scrutiny) | Mythic prize odds published transparently. No hard currency inside packages. |
| Scaling cost runaway | Budget alerts on $/DAU + Cloud Run concurrency tuning + aggressive caching |
| IP confusion with real-world postal services | Cleared brand search on "PEELED" — no conflicts at launch. Trademark filing in week 2. |
| "This gets boring in week 3" | Seasonal events + progression + social pull. Measure D30 relentlessly. |

---

## 21. Open Questions (for Daniel to decide)

- [ ] Do we want crypto/on-chain backing for Mythic badges (verifiable scarcity) or keep off-chain for simplicity?
- [ ] Is child-safe (COPPA/GDPR-K) a launch requirement or a v1.1 add?
- [ ] Target first soft-launch market: Philippines, Mexico, Israel, or Ireland?
- [ ] Do we run a creator program at launch or after the first seasonal refresh?

---

*This document is living. Update it every time a design decision is made or reversed.*
