# CLAUDE.md — PEELED

This file guides Claude Code (claude.ai/code) when working on this repo.
**Update this file after every non-trivial change** (new feature, schema change, architectural decision).

---

## 1. What is PEELED?

**PEELED** is a global viral mobile game where mysterious virtual packages pass between real players worldwide. Each package has a hidden number of layers — you have a limited time to peel one, revealing a hint, fact, or mini-reward. Peel the final layer and you win the package prize. Miss your window and the package keeps traveling. Watch the **Live Globe** to see packages zipping between cities in real time.

Inspired by the Israeli childhood game *"החבילה עוברת"* (The Package is Passing), reimagined for a global TikTok-era audience.

Core verb: *"you've been PEELED."*

**North Star metric:** Packages successfully opened per day.
**Secondary metrics:** DAU, D1/D7/D30 retention, share rate per opened package, referrals per user.

See [docs/GDD.md](docs/GDD.md) for the full Game Design Document.

---

## 2. Repo Layout

```
PEELED/
├── app/              Flutter client (iOS, Android, Web)
├── server/           FastAPI + Python game server
├── db/               SQL migrations, seeds, Postgres functions
├── docs/             GDD, architecture, API, monetization, deployment
├── infra/            Docker, Cloud Run, Kubernetes, Terraform
├── .github/          CI/CD workflows
└── scripts/          Dev tooling (seed, load-test, release scripts)
```

Keep this table in sync as the project evolves.

---

## 3. Tech Stack (and why)

| Layer | Choice | Why |
|---|---|---|
| Client | **Flutter 3.x** | One codebase for iOS + Android + Web. Best 60fps animations for the peel interaction. Daniel already ships Flutter apps via `App Architect AI`. |
| State | **Riverpod 2.x** | Compile-safe, testable, no BuildContext coupling. |
| Maps | **Mapbox GL (mapbox_maps_flutter)** | Beautiful globe projection, custom styles, smooth camera animations. |
| Auth & DB | **Supabase** (Postgres + RLS + Realtime + Auth) | SQL power, row-level security, built-in realtime channels, generous free tier for launch. |
| Realtime game svc | **FastAPI on Cloud Run** | Daniel's Python expertise; stateless scale-to-zero. |
| Queue / state | **Redis (Upstash)** | Package-in-flight state, rate limiting, leaderboards (ZSETs). |
| Push | **FCM (Firebase Cloud Messaging)** | Free, global, battle-tested. Used standalone — no full Firebase coupling. |
| Analytics | **PostHog + Supabase events** | Product analytics + funnel + session replay. |
| Observability | **Sentry** (client + server), **Grafana Cloud** | Error tracking + metrics. |
| CI/CD | **GitHub Actions + Fastlane** | Matches `App Architect AI` convention. |
| Hosting | **Cloud Run** (server), **Supabase** (db), **Cloudflare** (CDN) | Global edge, scale-to-zero, predictable cost. |

---

## 4. Core Architecture Principles

1. **Generic N-package routing.** The package router MUST support any number of live packages. Never hardcode for 2. See [server/app/services/package_router.py](server/app/services/package_router.py).
2. **Authoritative server.** The client never decides rewards, layer count, or who gets the next pass. Anti-cheat depends on this.
3. **Event-sourced package lifecycle.** Every transition (`created → sent → received → peeled → expired`) is an immutable row in `package_events`. Reconstruct any package state from its event log.
4. **Row-level security.** Users can read their own inventory, public leaderboards, and the public "live packages" view — nothing else. Enforced at Postgres, not app layer.
5. **Eventual-consistent map.** The live globe is a broadcast projection, not the source of truth. Dropped updates are fine.
6. **Mobile-first but web-playable.** All features must work on web too (shareable to any device).

Full detail in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## 5. Working Commands

### Flutter client
```bash
cd app
flutter pub get
flutter run -d chrome              # web dev
flutter run                        # connected device
flutter test                       # unit + widget
flutter test integration_test/     # e2e
flutter build apk --release        # Android release
flutter build ios --release        # iOS release (macOS only)
```

### Server
```bash
cd server
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -e ".[dev]"
uvicorn app.main:app --reload --port 8000
pytest                              # all tests
pytest --cov=app --cov-report=term  # with coverage
ruff check . && mypy app            # lint + types
```

### Database
```bash
cd db
psql "$DATABASE_URL" -f migrations/0001_init.sql
psql "$DATABASE_URL" -f migrations/0002_rls.sql
# ... etc
```

### Docker (full stack, local)
```bash
cd infra
docker compose up --build          # postgres + redis + server
```

---

## 6. Environment Variables

Never commit `.env`. Copy `.env.example` and fill in values.

**Server:**
- `DATABASE_URL` — Supabase Postgres connection string
- `SUPABASE_URL`, `SUPABASE_SERVICE_KEY` — admin operations
- `REDIS_URL` — Upstash or local Redis
- `FCM_SERVICE_ACCOUNT_JSON` — base64-encoded service account
- `SENTRY_DSN` — error tracking
- `JWT_SECRET` — signing game-session tokens
- `MAPBOX_TOKEN` — server-side tile access (for OG image generation)
- `ANTI_CHEAT_SIGNING_SECRET` — client action signatures

**Client (`app/.env`):**
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- `SERVER_BASE_URL` (e.g. `https://api.peeled.app`)
- `MAPBOX_PUBLIC_TOKEN`
- `POSTHOG_KEY`

---

## 7. Code Conventions

- **Immutable data.** Freezed models in Flutter, Pydantic v2 models in server, no mutation.
- **Small files.** Target 200–400 lines, hard cap 800. Split by feature, not by type.
- **Explicit errors.** No silent catches. Typed error envelopes at API boundary.
- **Never trust the client.** Validate at API boundary with Pydantic schemas. Re-verify server-side invariants.
- **Tests mandatory** for any new game logic (package router, layer engine, reward engine).

---

## 8. Security Non-Negotiables

- All gameplay actions (`peel`, `send`, `forward`) require a server-signed session token.
- Client-submitted timestamps are advisory — server clock is authoritative.
- Anti-cheat heuristics (see `server/app/services/anti_cheat.py`): impossible-speed peels, cross-device replay, emulator detection signals.
- Rate limits on every write endpoint.
- Secrets rotated quarterly; no secrets in client bundle.

---

## 9. User Context

- **Owner:** Daniel Salama (danielsalama88@gmail.com) — on vacation frequently; prefers autonomous, production-grade work.
- **Goal:** Passive income via viral app. Monetization is important but not at the cost of the core free experience.
- **Style:** Ships fast, delegates deeply, values test coverage and CI. Favors Python for backend and Flutter for mobile.
- **Principle:** "Go above and beyond to make this perfect." Daniel rewards ambition.

---

## 10. Current Status

- **Phase:** Initial scaffold + foundational systems (Week 1).
- **Built:** GDD, architecture doc, DB schema, FastAPI skeleton with package router, Flutter skeleton with peel-screen prototype, CI pipelines, Docker compose.
- **Next:** Payment integration (IAP + RevenueCat), Mapbox globe tuning, FCM push wiring, playtest telemetry, seasonal event engine.
- **Launch target:** Beta in 8 weeks. Soft-launch in 1 market, then global.

See [docs/ROADMAP.md](docs/ROADMAP.md) for milestones.

---

## 11. How to Work On PEELED

1. **Read the GDD first.** Every feature should ladder up to a pillar in [docs/GDD.md](docs/GDD.md).
2. **Plan before coding.** For anything >1 hour, write a short plan in a PR description.
3. **TDD for server game logic.** Router, layer engine, reward engine, anti-cheat — test-first, always.
4. **Reference [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** before adding new services.
5. **Update CLAUDE.md** if the tech stack, layout, or architecture changes.
