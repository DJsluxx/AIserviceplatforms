# PEELED — System Architecture

**Version:** 1.0 · **Last updated:** 2026-04-18

---

## 1. Goals

- Support **millions of concurrent users** globally with sub-250ms P99 peel latency.
- Be **authoritative**: server never trusts client for game state.
- Be **event-sourced**: every package transition is an append-only fact.
- Be **generic**: the routing engine has no knowledge of how many packages are live.
- Be **cost-sane**: unit cost < $0.002/DAU at scale.

---

## 2. High-Level Diagram

```
                         ┌────────────────────────┐
                         │   Flutter clients      │ (iOS / Android / Web)
                         └───────────┬────────────┘
                                     │ HTTPS + WebSocket + Realtime
                ┌────────────────────┼────────────────────┐
                │                    │                    │
        ┌───────▼───────┐    ┌───────▼───────┐    ┌───────▼────────┐
        │  Supabase     │    │   FastAPI     │    │   FCM          │
        │  (Postgres +  │    │  game server  │    │   (push)       │
        │  RLS + Auth + │    │  on Cloud Run │    └────────────────┘
        │  Realtime)    │    └───────┬───────┘
        └───────┬───────┘            │
                │                    │
                │             ┌──────▼──────┐
                │             │   Redis     │ (Upstash)
                │             │  (state +   │
                │             │  rate-limit)│
                │             └─────────────┘
                │
          ┌─────▼─────┐
          │  Cloudflare│
          │  CDN + R2  │
          └───────────┘
```

Observability: **Sentry** (client + server errors), **Grafana Cloud** (metrics), **PostHog** (product analytics).

---

## 3. Data Model (Postgres)

Full DDL in [db/migrations/0001_init.sql](../db/migrations/0001_init.sql).

### 3.1 Core tables

- `users` — profile, auth-linked via Supabase Auth (`auth.users.id`)
- `packages` — current state (read-model, periodically materialised from events)
- `package_events` — append-only log (source of truth)
- `package_layers` — pre-generated layers (hidden behind RLS)
- `peels` — one row per peel action
- `inventory` — per-user item counts (coins, power-ups, stickers)
- `friendships` — directed edges (follow-model)
- `leaderboard_snapshots` — periodic snapshots (last-hour windows)
- `notifications_sent` — dedup + cap enforcement
- `device_tokens` — FCM tokens per user
- `seasons` — active seasonal theme metadata
- `audit_anti_cheat` — flagged actions + device fingerprints

### 3.2 Read vs source-of-truth

- **Source of truth:** `package_events` (append-only, partitioned by day).
- **Materialised views:** `packages_current`, `leaderboards_weekly`, `live_map_view`.
- A worker rolls events into `packages_current` synchronously in the same transaction that writes the event.

### 3.3 Row-Level Security

Every table has RLS enabled. Policies allow:
- Users read own row in `users`, `inventory`, `device_tokens`.
- Users read `packages_current` only where they are `current_holder_id` OR package is in public view.
- Users read `leaderboards_weekly` fully.
- `package_layers` is **never** readable client-side (layer reveal goes through server endpoint).
- Service role (server) bypasses all RLS.

Policies in [db/migrations/0002_rls.sql](../db/migrations/0002_rls.sql).

---

## 4. Services

### 4.1 FastAPI server (`server/`)

Stateless. Deployed to Cloud Run, auto-scales on concurrency.

Routes:

| Path | Method | Purpose |
|---|---|---|
| `/api/v1/auth/session` | POST | Exchange Supabase JWT for game session token |
| `/api/v1/packages/inbox` | GET | List packages currently held by user |
| `/api/v1/packages/{id}/peel` | POST | Peel one layer (signed action) |
| `/api/v1/packages/{id}/pass` | POST | Pass to random |
| `/api/v1/packages/{id}/send-to-friend` | POST | Pass to specific friend |
| `/api/v1/packages/create` | POST | User-initiated new package (uses token currency) |
| `/api/v1/map/live` | GET | Current live-map snapshot |
| `/api/v1/leaderboard/{kind}` | GET | Leaderboard (cached 10s) |
| `/api/v1/users/me` | GET/PATCH | Profile |
| `/api/v1/friends/...` | various | Friendships |
| `/api/v1/shop/...` | various | IAP + tokens |
| `/ws/map` | WS | Live map broadcast |

### 4.2 Workers

- **`package_ticker`** — polls Redis ZSET every 500ms for expired deadlines; re-routes. Implemented as a Cloud Run **job** running continuously (single-replica; leader-elect via Redis lock).
- **`seasonal`** — rolls new season every 6 weeks; updates config atomically.
- **`cleanup`** — archives packages older than 30 days, compacts events.
- **`notification_bundler`** — aggregates low-priority notifications for daily 7pm-local send.
- **`leaderboard_snapshotter`** — writes hourly snapshots for historical views.

### 4.3 Supabase

- **Auth** — email + Apple + Google sign-in; anonymous sessions for onboarding.
- **Postgres** — primary store.
- **Realtime** — `live_map` broadcast channel (not per-user).
- **Storage** — user avatars, sticker images, share-card renders.
- **Edge Functions** — *not used in v1*; all logic in FastAPI.

### 4.4 Redis (Upstash)

- **`deadlines`** ZSET — package_id → unix_ms of expiration. Ticker polls `ZRANGEBYSCORE 0 now`.
- **`rate_limits:*`** — token buckets per user/IP/action.
- **`leaderboards:{kind}:{period}`** ZSET.
- **`live_packages`** SET — IDs of in-flight packages (fast cardinality check).
- **`session:{token}`** — session metadata with TTL.

---

## 5. The Package Router (generic N-package design)

**File:** [server/app/services/package_router.py](../server/app/services/package_router.py)

### 5.1 Contract

```python
class PackageRouter:
    def route_next(self, package: Package, sender: User, mode: RouteMode) -> RouteDecision:
        """
        Decide where a package goes next. Pure function of:
          - current package state
          - sender identity
          - mode (RANDOM | SEND_TO_FRIEND | REROUTE_AFTER_EXPIRE)
        Returns: next recipient + deadline + geo hop metadata.
        """
```

It does **not** know how many packages are live. Each package passes through the router independently. Routing is stateless except for a short-lived Redis cache of online-user sets.

### 5.2 Recipient selection

Weighted random pick from eligible pool (online, not recently-received, not blocked, meets rarity tier). Weights are config-driven.

### 5.3 Concurrency

Multiple packages can route simultaneously. The only contended resource is:
- The chosen recipient's **current-holder slot** — one user can hold at most 3 packages at once (config).
- Enforced via Postgres advisory lock keyed on `user_id`.

If slot full → recipient skipped, router retries next candidate.

### 5.4 Expiration handling

When deadline passes:
1. Ticker reads expired packages from Redis ZSET.
2. For each: writes `package_events (type='expired_hop')`, calls `router.route_next(mode=REROUTE_AFTER_EXPIRE)`.
3. New recipient gets push + deadline. Package rarity may downgrade if >5 failed hops.

This is the **only** way packages can die — no client action can kill a package they hold; they can only pass it or let it expire.

---

## 6. Realtime: the Live Globe

### 6.1 Broadcast design

- Supabase Realtime broadcasts to channel `live_map` (single public channel).
- Every router decision publishes a tiny payload:
  ```json
  {"t": "hop", "pkg": "abc123", "rarity": "epic",
   "from": {"lat": 48.8, "lng": 2.3}, "to": {"lat": 35.7, "lng": 139.7},
   "ts": 17312934092}
  ```
- Clients subscribe once on app-open. Payloads are < 200 bytes.

### 6.2 Back-pressure

- Server throttles broadcasts at 100/sec (per region). If exceeded, lower-rarity hops are dropped from the feed (still persist to DB).
- Client renders a max of 40 concurrent arcs; new hops enqueue, oldest fade.

### 6.3 Privacy

- Only city-level coords are broadcast (rounded to nearest 0.1°).
- Usernames are **not** in the map stream. Only rarity + arcs.
- Tapping a package arc hits the API for lightweight public-info (rarity, layers peeled) — no user identity.

---

## 7. Client Architecture (Flutter)

### 7.1 Layers

```
presentation (Screens + Widgets)
    │
    ▼
application (Riverpod providers — state + side-effects)
    │
    ▼
domain (Models + use-cases — pure Dart)
    │
    ▼
data (Repositories — API + DB + cache)
    │
    ▼
infrastructure (HTTP / Supabase / FCM / local storage)
```

- `features/*` bundles all four layers by domain (auth, home, package, worldmap, etc.)
- `core/*` has cross-cutting (router, theme, network interceptors).
- `shared/*` has reusable widgets.

### 7.2 State management

**Riverpod 2.x** with code generation.

```
// Example
@riverpod
Future<InboxState> inbox(InboxRef ref) async { ... }
```

### 7.3 Animations

- **Rive** for peel + wrapper + confetti cinematics.
- **flutter_animate** for micro-interactions (toast bounces, number tickers).
- **flutter_map + flutter_mapbox_gl** for the globe.
- **lottie** for onboarding illustrations.

### 7.4 Offline behaviour

Read-only is offline-capable (show cached inbox, last-known globe snapshot). Writes require connectivity and fail gracefully with a retry queue.

---

## 8. Security

### 8.1 Action signing

All gameplay writes require a `SignedAction` header:
```
X-PEELED-Action: <base64url(payload)>.<base64url(signature)>
payload = { action: "peel", package_id, nonce, exp, user_id }
signature = HMAC-SHA256(payload, ANTI_CHEAT_SIGNING_SECRET)
```
Nonces single-use, cached in Redis with TTL = action expiry. Replays rejected.

### 8.2 Device integrity

Android: Play Integrity API. iOS: DeviceCheck + App Attest. Verified on sensitive actions (final-layer peel, IAP callback). Fails → shadow-ban bucket.

### 8.3 Rate limits (per user, unless noted)

- `peel`: 30/min, 400/hour
- `pass`: 30/min, 400/hour
- `create_package`: 5/day (costs tokens)
- `send_to_friend`: 10/day
- `report`: 20/day

### 8.4 Secrets

- Stored in Google Secret Manager + mounted at Cloud Run start.
- Never present in client bundle.
- Rotated quarterly.

---

## 9. Observability

### 9.1 Metrics (Prometheus → Grafana Cloud)

- `peeled_packages_in_flight`
- `peeled_peels_total{rarity}`
- `peeled_peel_latency_seconds` (histogram)
- `peeled_router_decision_latency_seconds`
- `peeled_notification_sent_total{category}`
- `peeled_anti_cheat_flags_total{reason}`

### 9.2 Tracing

OpenTelemetry auto-instrumentation on FastAPI + Postgres + Redis clients. Traces sampled at 1% in prod, 100% in staging.

### 9.3 Logs

Structured JSON. `request_id`, `user_id`, `package_id` always present. Shipped to Cloud Logging.

### 9.4 Alerting

- P99 peel latency > 500ms for 5min → page
- Cloud Run 5xx > 1% for 2min → page
- Redis unavailable → page
- Packages-in-flight drops below 500 during peak → investigate (supply problem)
- Anti-cheat flag rate > 1% → investigate (attack or bug)

---

## 10. Deployment

See [docs/DEPLOYMENT.md](DEPLOYMENT.md).

TL;DR:
- Server: GitHub Actions builds container → pushes to Artifact Registry → `gcloud run deploy`.
- DB migrations: run as a one-shot Cloud Run job before server rollout.
- Flutter: Fastlane lanes for TestFlight / Play internal testing. Web: Cloudflare Pages.

---

## 11. Environments

| Env | DB | Redis | Server | Client |
|---|---|---|---|---|
| `local` | Docker Postgres | Docker Redis | `uvicorn --reload` | `flutter run` |
| `dev` | Supabase project `peeled-dev` | Upstash dev | Cloud Run `peeled-api-dev` | TestFlight / Internal track |
| `prod` | Supabase project `peeled` | Upstash prod | Cloud Run `peeled-api` | App Store / Play |

---

## 12. Future (v2+) considerations

- **Regional write sharding** by user home-region (packages travelling across regions via routed mailbox pattern).
- **Event-streaming** on Kafka/Pulsar if Supabase Realtime becomes a bottleneck.
- **WASM game logic** running on client for offline speculative peel animations (server still authoritative).
- **AR Peel** — ARKit / ARCore integration for the "point your phone at a package" experience.
- **Creator economy backend** — revenue share engine for user-designed themes.

---

## 13. Decision log

| Date | Decision | Rationale |
|---|---|---|
| 2026-04-18 | Flutter over React Native | 60fps peel animation fidelity, Daniel's existing Flutter pipeline. |
| 2026-04-18 | Supabase over Firebase | SQL + RLS + realtime in one, fits Daniel's Postgres preference. |
| 2026-04-18 | FastAPI for game server, not Supabase Edge Functions | Long-running workers + complex game logic easier to test in Python. |
| 2026-04-18 | FCM over APNs/Firebase full stack | Standalone usage keeps us decoupled from rest of Firebase. |
| 2026-04-18 | Event-sourced packages | Audit + replay + reliable post-hoc analytics. |
