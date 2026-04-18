# PEELED — Roadmap

**Last updated:** 2026-04-18

---

## Milestones

### M0 — Foundation (Week 1) — ✅ scaffolding in progress
- [x] Name decision: **PEELED**
- [x] GDD v1
- [x] Architecture doc
- [x] DB schema + RLS
- [x] FastAPI skeleton with package router
- [x] Flutter skeleton with peel-screen prototype
- [x] CI pipelines
- [x] Docker compose for local dev

### M1 — Core Loop Playable (Weeks 2–3)
- [ ] End-to-end: receive → peel → pass → receive again (no bots yet)
- [ ] Live globe with 5 concurrent arcs
- [ ] Auth (email + anon)
- [ ] FCM push fully wired
- [ ] 3 rarity tiers working with reward delivery
- [ ] Basic leaderboard (weekly global)
- [ ] Share card generator (PNG)

### M2 — Social + Monetization (Weeks 4–5)
- [ ] Friends (follow model) + send-to-friend
- [ ] Daily PEELED streak
- [ ] PEELED Plus subscription (RevenueCat)
- [ ] Hard currency IAP + token shop
- [ ] Rewarded ads (AdMob or IronSource)
- [ ] Deep linking for share cards

### M3 — Scale & Safety (Weeks 6–7)
- [ ] Anti-cheat v1 (action signing, device integrity, shadow-ban)
- [ ] Rate limiting everywhere
- [ ] Load test: 10k concurrent users, 500 packages in-flight
- [ ] Observability: Sentry + Grafana + PostHog dashboards
- [ ] Safety: report/block, username moderation
- [ ] Privacy review (GDPR + CCPA)

### M4 — Beta Launch (Week 8)
- [ ] TestFlight public beta in 1 market (Philippines OR Ireland)
- [ ] 2,000 seed-bot packages/day during cold start
- [ ] Daily sanity check + hotfix lane ready
- [ ] Ad spend $500 for install test
- [ ] Measure D1/D7 retention

### M5 — Soft Launch (Week 10)
- [ ] Fix top issues from beta
- [ ] Seasonal theme #1 ("Launch")
- [ ] Launch in 3 markets
- [ ] PR push + influencer seeding

### M6 — Global Launch (Week 14)
- [ ] Global rollout
- [ ] Seasonal theme #2 ready
- [ ] First Mythic sponsored package
- [ ] Press kit + App Store feature pitch

---

## Post-Launch Backlog (priority order)

1. Clans + group missions
2. Voice notes on packages
3. "Inherit" mode (24h+ in-flight packages)
4. AR Peel (ARKit/ARCore)
5. PEELED Live (synchronised global event)
6. Apple Watch / Wear OS complication
7. PEELED Maker (creator economy)
8. Cross-platform watch widget
9. Charity Mythics
10. Regional write-sharding for DB

---

## Known Risks to Schedule

- Mapbox globe performance on Android <10 devices
- FCM delivery delays in certain regions (China mainland fallback plan needed)
- App Store review cycle for IAP — bake in 1-week buffer
- Cold-start seeding dynamics may need rebalancing after week 1 telemetry

---

## Definitions of Done (per milestone)

A milestone is only "done" when:
1. Feature works end-to-end in staging
2. Tests added (unit + integration where applicable)
3. Observability wired (metrics + logs)
4. Docs updated (CLAUDE.md, API.md if endpoint-level)
5. No CRITICAL or HIGH code-reviewer issues open
