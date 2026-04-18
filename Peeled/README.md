# PEELED

> **A global viral game where mysterious packages pass between real players worldwide. Peel a layer. Win the prize. Get PEELED.**

[![server](https://img.shields.io/badge/server-FastAPI-009688)]()
[![client](https://img.shields.io/badge/client-Flutter%203.x-02569B)]()
[![db](https://img.shields.io/badge/db-Supabase%20Postgres-3ECF8E)]()
[![realtime](https://img.shields.io/badge/realtime-WebSocket%20%7C%20Redis-DC382D)]()
[![ci](https://img.shields.io/badge/CI-GitHub%20Actions-2088FF)]()

---

## The concept in one screen

A mysterious package lands in your inbox. You have **38 seconds** to peel one layer. The layer reveals a hint, a mini-reward, a trap, or the final prize. Miss your window and the package keeps traveling around the world — you can watch it live on the globe.

Inspired by *"החבילה עוברת"* (The Package is Passing), reimagined for the TikTok-era.

Core verb: **"you've been PEELED."**

---

## Monorepo layout

```
PEELED/
├── app/          Flutter 3.x client (iOS, Android, Web)
├── server/       FastAPI + Python game server
├── db/           Postgres migrations, RLS, stored functions
├── docs/         GDD, architecture, API, design, roadmap
├── infra/        Dockerfiles + docker-compose for local full-stack
├── scripts/      Dev tooling (seed, load-test)
└── .github/      CI/CD workflows (server, flutter, deploy)
```

---

## Tech stack at a glance

| Layer                 | Choice                                     |
| --------------------- | ------------------------------------------ |
| Client                | Flutter 3.x, Riverpod 2.x, Rive, Mapbox GL |
| Backend               | FastAPI, Pydantic v2, SQLAlchemy 2 async   |
| Database              | Supabase Postgres + Row-Level Security     |
| Cache / pub-sub       | Redis (Upstash in prod)                    |
| Auth                  | Supabase Auth + signed session JWT         |
| Anti-cheat            | HMAC-signed actions + Play Integrity       |
| Push                  | FCM (standalone, no full Firebase)         |
| Observability         | Sentry, Grafana Cloud, PostHog             |
| CI/CD                 | GitHub Actions                             |
| Hosting (server)      | Cloud Run                                  |

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for why each was chosen.

---

## Quick start — local full stack

**Prerequisites:** Docker Desktop, Flutter 3.x, Python 3.12.

```bash
# 1. Boot postgres + redis + server + ticker
cd infra
docker compose up --build

# 2. Run Flutter client against local server
cd ../app
flutter pub get
flutter run -d chrome
```

Server will be at `http://localhost:8000` (OpenAPI docs at `/docs`).

---

## Server — develop locally

```bash
cd server
python -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"

cp ../.env.example .env
# fill in DATABASE_URL, REDIS_URL, JWT_SECRET, ANTI_CHEAT_SIGNING_SECRET

uvicorn app.main:app --reload --port 8000
```

### Tests

```bash
pytest -q --cov=app --cov-report=term-missing tests/unit
ruff check app tests
mypy app
```

The N-package router regression test (`tests/unit/test_package_router.py::test_scales_to_n_packages`) proves routing is generic for N=[1, 3, 5, 20] simultaneous packages — never hardcoded for 2.

---

## Client — develop locally

```bash
cd app
flutter pub get

# Web (fastest iteration)
flutter run -d chrome

# Native
flutter run                         # connected device
flutter build apk --release         # Android
flutter build ios --release         # iOS (macOS only)
```

### Tests

```bash
flutter analyze --no-fatal-infos
flutter test --reporter expanded
flutter test integration_test/
```

---

## Database

Migrations are plain SQL files, applied in order:

```bash
psql "$DATABASE_URL" -f db/migrations/0001_init.sql
psql "$DATABASE_URL" -f db/migrations/0002_rls.sql
# ... additional migrations in order
```

Package lifecycle is **event-sourced**: every `created → sent → received → peeled → expired` transition is an immutable row in `package_events`. State at any point is reconstructible from the event log.

---

## Core architecture principles

1. **Generic N-package routing.** The router scores every candidate recipient independently; `pick_recipients_for_batch(...)` handles any number of live packages in parallel.
2. **Authoritative server.** The client never decides rewards, layer count, or who gets the next hop. All gameplay actions require a server-signed HMAC action token that is single-use via Redis.
3. **Event-sourced package lifecycle.** Every transition is an immutable row.
4. **Row-level security.** Users can read their own inventory, public leaderboards, the public "live packages" view — nothing else. Enforced in Postgres.
5. **Eventual-consistent live map.** The globe is a broadcast projection, not the source of truth. Dropped updates are fine.
6. **Mobile-first but web-playable.** Every feature works on web so it is shareable to any device.

---

## Environment variables

Copy [`.env.example`](.env.example) and fill in values. Never commit real secrets.

**Server:** `DATABASE_URL`, `REDIS_URL`, `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `SUPABASE_JWT_SECRET`, `JWT_SECRET`, `ANTI_CHEAT_SIGNING_SECRET`, `FCM_SERVICE_ACCOUNT_JSON`, `SENTRY_DSN`, `MAPBOX_TOKEN`.

**Client (`app/.env`):** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SERVER_BASE_URL`, `MAPBOX_PUBLIC_TOKEN`, `POSTHOG_KEY`.

---

## Docs

| Doc                                            | What                                                              |
| ---------------------------------------------- | ----------------------------------------------------------------- |
| [docs/GDD.md](docs/GDD.md)                     | Game Design Document — pillars, loops, progression, monetization  |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)   | System architecture, routing algorithm, anti-cheat, data model    |
| [docs/API.md](docs/API.md)                     | REST + WebSocket API reference                                    |
| [docs/DESIGN.md](docs/DESIGN.md)               | Visual identity, motion, tokens, rarity palettes                  |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)       | Cloud Run, Supabase, release process                              |
| [docs/ROADMAP.md](docs/ROADMAP.md)             | Milestones, beta, launch targets                                  |
| [CLAUDE.md](CLAUDE.md)                         | Operating guide for Claude Code / future contributors             |

---

## Security non-negotiables

- Every gameplay write requires a server-signed **HMAC action token**, single-use via Redis `SETNX` nonce.
- Client timestamps are advisory; server clock is authoritative.
- Anti-cheat: sub-250ms peel intervals flagged, device integrity via Play Integrity / App Attest, shadow-ban on threshold breach.
- Rate limits on every write endpoint.
- Row-Level Security enforced at Postgres, not the app layer.
- Secrets rotated quarterly. No secrets in the client bundle.

---

## Status

**Phase:** Initial scaffold + foundational systems.
**Built:** GDD, architecture, DB schema, FastAPI server (auth, packages, map WS, ticker, cleanup, leaderboard), Flutter client (peel screen, map, inbox, juicy buttons), CI (server + flutter), Docker compose.
**Next:** Payments (IAP + RevenueCat), Mapbox globe tuning, FCM push wiring, playtest telemetry, seasonal events.
**Launch target:** Closed beta in 8 weeks; soft-launch single market, then global.

---

## License

All rights reserved © 2026 Daniel Salama. Not for redistribution.
