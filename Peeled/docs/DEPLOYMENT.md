# PEELED — Deployment Guide

---

## Environments

| Env | DB | Redis | Server | Client |
|---|---|---|---|---|
| `local` | Docker Postgres | Docker Redis | `uvicorn --reload` | `flutter run` |
| `dev` | Supabase `peeled-dev` | Upstash free | Cloud Run `peeled-api-dev` | TestFlight / Play internal |
| `prod` | Supabase `peeled` | Upstash pro | Cloud Run `peeled-api` | App Store / Play |

---

## Prerequisites

- Google Cloud project with billing enabled
- Artifact Registry repo `peeled-server`
- Supabase organisation + 2 projects (`peeled-dev`, `peeled`)
- Upstash Redis (free for dev, pro for prod)
- Cloudflare account for CDN + R2 (share-card hosting)
- Firebase project for FCM only (no other Firebase services)
- RevenueCat account for IAP + subscription management
- Apple Developer + Google Play developer accounts
- Sentry project
- PostHog project (cloud or self-hosted)

---

## First-time setup

### 1. Supabase
```bash
# In each Supabase project, run migrations:
psql "$DATABASE_URL" -f db/migrations/0001_init.sql
psql "$DATABASE_URL" -f db/migrations/0002_rls.sql
psql "$DATABASE_URL" -f db/migrations/0003_functions.sql
psql "$DATABASE_URL" -f db/seed/0001_seed_seasons.sql
```

Enable realtime broadcast on the `live_map` channel via Supabase dashboard
(Settings → Realtime → enable broadcast for channels with prefix `live_`).

Create storage buckets: `avatars` (public-read, 5MB cap), `share-cards` (public-read,
1MB cap, signed-write via server).

### 2. Google Cloud
```bash
gcloud config set project peeled-prod
gcloud auth configure-docker <region>-docker.pkg.dev
gcloud artifacts repositories create peeled-server \
  --repository-format=docker --location=$REGION
```

### 3. Secrets
Store in Google Secret Manager:
```
peeled/database-url
peeled/supabase-service-key
peeled/redis-url
peeled/fcm-service-account
peeled/sentry-dsn-server
peeled/jwt-secret
peeled/anti-cheat-signing-secret
peeled/mapbox-server-token
```

Grant Cloud Run service account `roles/secretmanager.secretAccessor` for each.

---

## Build + Deploy the server

```bash
# From repo root
docker build -f infra/docker/Dockerfile.server -t peeled-api:$(git rev-parse --short HEAD) .
docker tag peeled-api:$(git rev-parse --short HEAD) $REGION-docker.pkg.dev/$PROJECT/peeled-server/api:$(git rev-parse --short HEAD)
docker push $REGION-docker.pkg.dev/$PROJECT/peeled-server/api:$(git rev-parse --short HEAD)

gcloud run deploy peeled-api \
  --image $REGION-docker.pkg.dev/$PROJECT/peeled-server/api:$(git rev-parse --short HEAD) \
  --region $REGION \
  --concurrency 80 \
  --cpu 1 --memory 512Mi \
  --min-instances 1 \
  --max-instances 100 \
  --allow-unauthenticated \
  --set-secrets "DATABASE_URL=peeled/database-url:latest,\
SUPABASE_SERVICE_KEY=peeled/supabase-service-key:latest,\
REDIS_URL=peeled/redis-url:latest,\
JWT_SECRET=peeled/jwt-secret:latest,\
ANTI_CHEAT_SIGNING_SECRET=peeled/anti-cheat-signing-secret:latest,\
SENTRY_DSN=peeled/sentry-dsn-server:latest,\
FCM_SERVICE_ACCOUNT_JSON=peeled/fcm-service-account:latest,\
MAPBOX_TOKEN=peeled/mapbox-server-token:latest"
```

CI performs this automatically via `.github/workflows/deploy.yml` on tag push.

---

## Deploy the ticker worker

The ticker is a separate Cloud Run **job** (always-on single replica):

```bash
gcloud run jobs deploy peeled-ticker \
  --image $REGION-docker.pkg.dev/$PROJECT/peeled-server/api:$(git rev-parse --short HEAD) \
  --command "python" --args "-m,app.workers.package_ticker" \
  --region $REGION \
  --tasks 1 --max-retries 0 \
  --set-secrets "DATABASE_URL=peeled/database-url:latest,REDIS_URL=peeled/redis-url:latest,..."
```

We use **Cloud Scheduler → Cloud Run Job** cron at `*/5 * * * *` to trigger a
self-healing wakeup (the job holds a leader lock in Redis and loops internally
for ~5 minutes before exiting cleanly — this is a cost-effective pattern for
continuous background work on Cloud Run).

---

## Deploy the client

### Android (Play Console)
```bash
cd app
fastlane android internal       # internal track
fastlane android beta           # open beta
fastlane android release        # production (manual rollout %)
```

### iOS (TestFlight / App Store)
```bash
cd app
fastlane ios beta               # TestFlight
fastlane ios release            # App Store review
```

### Web (Cloudflare Pages)
Auto-deployed on push to `main` via Cloudflare Pages GitHub integration:
- Build command: `cd app && flutter build web --release`
- Output dir: `app/build/web`

---

## Rollback

### Server
```bash
gcloud run services update-traffic peeled-api --region $REGION \
  --to-revisions peeled-api-00042=100
```

### DB
Migrations are append-only by convention. Never down-migrate in prod. If a
migration introduces a broken constraint, push a fixing forward migration.

### Client
iOS: reject app submission or use phased rollout.
Android: halt rollout in Play Console.

---

## Observability Dashboards

- Grafana Cloud board: **PEELED - Prod Overview** (packages in flight, P99
  peel latency, push delivery, error rate)
- Sentry project dashboards for client + server
- PostHog funnel: Install → Onboarding → First Peel → D1 Retention
- Supabase logs for DB slow queries
- Cloud Run revision metrics (request count, latency, instance count)

---

## Runbooks (high-level)

See `docs/runbooks/` (created post-launch). Starter incidents to document:
- P99 peel latency spike
- Redis unavailable
- Supabase realtime broadcast failing
- FCM delivery rate drop
- Cold-start package supply dropping
- Sudden anti-cheat flag spike

---

## Cost model (estimated, 100k DAU)

| Service | Monthly |
|---|---|
| Supabase Pro | $25 + usage ~$40 |
| Upstash Redis Pro | $80 |
| Cloud Run | $60 (burst auto-scale) |
| Cloud Storage + CDN egress | $15 |
| Cloudflare (Pages + R2) | $0–10 |
| FCM | $0 |
| Sentry | $26 (Team) |
| PostHog (self-hosted on GCE) | $50 |
| Mapbox (globe tiles) | $0–$100 |
| **Total est.** | ~$300/mo |

Per-DAU cost target: ≤ $0.002.
