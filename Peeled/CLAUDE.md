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

---

## 12. Local Dispatch & Max-Capability Session

This repo is wired so a dispatched Claude Code session running on Daniel's **local PC** boots with maximum tools, maximum model, and a clear "go beyond" playbook. When any new session starts here it MUST:

### 12.1 Model + thinking
- Use **`claude-opus-4-7`** (Opus 4.7, 1M context). Do not downgrade silently.
- Run in **extended-thinking / ultra-think** mode for any non-trivial task (anything that touches server game logic, DB schema, auth, payments, anti-cheat, or cross-cutting refactors).
- Prefer **plan-first**: write a short plan → get it reviewed by the in-session `Plan` subagent → then execute.
- Before declaring done, run a **self-critique pass**: "what would a senior reviewer reject?" and fix it.

### 12.2 Permissions + local tools (OWNER MODE)
- Permissions, hooks, model, and env are pinned in [`.claude/settings.json`](.claude/settings.json).
- **Daniel is the sole owner**, so sessions run in **`bypassPermissions`** mode. No approval prompts, no friction. Act decisively.
- Allowlist is effectively everything: `Bash(*)`, `Read(**)`, `Write(**)`, `Edit(**)`, `WebFetch`, `WebSearch`. Use any local tool that helps: `flutter`, `dart`, `python`, `pytest`, `ruff`, `mypy`, `docker`, `docker compose`, `psql`, `redis-cli`, `supabase`, `npm`/`pnpm`/`yarn`, full `git` + `gh`, anything else on the machine.
- **Floor-level denies only** (the only things we will NOT do): `rm -rf /`, `rm -rf ~`, `mkfs*`, `dd if=* of=/dev/*`, `shutdown`, `reboot`, fork bombs. Everything else — including `git push --force`, `git reset --hard`, branch deletion — is the owner's call; do it when the owner asks or when root-causing clearly requires it.
- **Push directly to `main`** when the task is done and the checks are green. Feature branches are optional, not mandatory. PRs are optional — open one only if the change warrants review or staging gating. Daniel merges every PR to `main` anyway.
- Never commit `.env*`, private keys, or service-account JSON (that's a *secrets* floor, not a permissions one).

### 12.3 Subagents (use them — they exist for a reason)
- **`Explore`** — open-ended codebase search and "where does X live?". Use before editing unfamiliar areas.
- **`Plan`** — architect agent. Mandatory for any change touching `server/app/services/package_router.py`, `layer_engine.py`, `reward_engine.py`, `anti_cheat.py`, or `db/migrations/*`.
- **`general-purpose`** — multi-step research tasks that would otherwise pollute the main context.
- Launch independent subagents **in parallel** (one message, multiple tool calls). Never serialize independent work.

### 12.4 Session start checklist (run every dispatched session)
1. `git status` + `git rev-parse --abbrev-ref HEAD` — see the state. Being on `main` is fine; owner-mode sessions push there directly.
2. Re-read this file, [docs/GDD.md](docs/GDD.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/ROADMAP.md](docs/ROADMAP.md).
3. `cd server && ruff check . && mypy app && pytest -q` — baseline must be green before you touch anything.
4. `cd app && flutter analyze && flutter test` — same for the client.
5. `docker compose -f infra/docker-compose.yml up -d postgres redis` — have real infra for integration work.
6. Only after 1–5 pass: start the requested task.

### 12.5 Definition of "above-and-beyond"
Daniel's rule: *"Go above and beyond to make this perfect."* That means every session does ALL of the following, not just the one the task asked about:

1. **Correct.** Passes existing tests + new tests. TDD for game logic.
2. **Observable.** Sentry breadcrumbs / structured logs / PostHog events where they matter.
3. **Safe.** Rate-limited, RLS-checked, server-authoritative. Anti-cheat signature on any new gameplay action.
4. **Performant.** No N+1s, no unbounded queries, no blocking I/O on the event loop. Target 60 fps on the peel animation, <100 ms p95 on gameplay endpoints.
5. **Polish on the way.** Any rough edge you pass — a weird typo, an ugly log line, a confusing variable name, a jank animation, a slow query, a missing loading state, a dead code path, an inconsistent spacing in the UI — **fix it in the same PR**. You don't need permission to polish.
6. **Efficiency + optimization scan.** Each task ends with a conscious pass: *"Where is this slower than it needs to be? Where do we waste memory, tokens, bandwidth, DB round-trips, cold-start time, bundle size? What can I make 2× better in 5 minutes?"* Fix the top 1–3 wins; note the rest in [docs/ROADMAP.md](docs/ROADMAP.md).
7. **Creativity + "what's next?"** At the end of each task, ask: *"If I were Daniel, what would I wish this session had also thought of? What's the next adjacent improvement — a nicer animation, a better empty state, a smarter default, a cleverer reward, a viral share-mechanic, a smaller install size, a faster onboarding?"* Implement one of those. Queue the rest in [docs/ROADMAP.md](docs/ROADMAP.md) under "Post-Launch Backlog" or a new "Ideas" section.
8. **UI / UX mindset.** Every visible change has to *feel* premium. Check: typography rhythm, spacing scale, color contrast (WCAG AA), micro-interactions, haptics, sound, empty states, loading skeletons, error states, success celebrations, dark mode, safe-area insets, one-handed reachability, localization readiness. If the UI is not delightful, it is not done.
9. **Documented.** Update [CLAUDE.md](CLAUDE.md), [docs/API.md](docs/API.md), [docs/ROADMAP.md](docs/ROADMAP.md), [docs/DESIGN.md](docs/DESIGN.md) when relevant.
10. **Shippable.** Lint + type + tests green; migration reversible; if you opened a PR, it explains the *why* and the tradeoffs. Otherwise push to `main`.

**The "ask yourself next" loop** is mandatory. Every task closes with a short "Next-Improvements" section in the commit/PR body listing 3–5 concrete follow-ups the session noticed but didn't do (with a rough size / value estimate). This is how PEELED compounds.

### 12.6 Dispatching more sessions from inside a session
When *this* session dispatches a new Claude session (e.g. via `claude dispatch`, a worktree agent, or a CI-triggered run) it MUST pass the same guardrails forward:
- Point the new session at this repo and at **this CLAUDE.md**.
- Force `claude-opus-4-7` + extended thinking.
- Inherit [`.claude/settings.json`](.claude/settings.json) (owner-mode, bypass permissions).
- Push directly to `main` when the task is green; feature branches are optional.
- See [`DISPATCH_PROMPT.md`](DISPATCH_PROMPT.md) for the canonical prompt to hand to a dispatched session.

### 12.7 Update discipline
Whenever you change tech stack, add a service, change a migration, or alter a core principle: **update this CLAUDE.md in the same PR**. A stale CLAUDE.md is treated as a bug.
