# PEELED — API Reference

**Base URL (prod):** `https://api.peeled.app`
**Base URL (dev):** `https://api-dev.peeled.app`

All requests require a bearer token from Supabase Auth:
```
Authorization: Bearer <supabase_jwt>
```

All gameplay writes additionally require a signed action header (issued by server):
```
X-PEELED-Action: <base64(payload)>.<base64(signature)>
```

---

## Envelope

All responses use the envelope:

```json
{ "ok": true, "data": { ... }, "meta": { "request_id": "..." } }
```
or on error:
```json
{ "ok": false, "error": { "code": "RATE_LIMITED", "message": "...", "retry_after": 5 }, "meta": { "request_id": "..." } }
```

Error codes:
- `UNAUTHENTICATED` `FORBIDDEN` `NOT_FOUND` `VALIDATION_FAILED`
- `RATE_LIMITED` `PACKAGE_EXPIRED` `INVENTORY_FULL`
- `ACTION_SIGNATURE_INVALID` `NONCE_REPLAYED` `CHEAT_FLAGGED`
- `SERVER_ERROR`

---

## Endpoints

### Auth

#### `POST /api/v1/auth/session`
Exchange a Supabase JWT for a game session + grab a fresh signed-action token.

**Request**
```json
{ "device_fingerprint": "a8f...", "device_integrity_token": "..." }
```
**Response**
```json
{ "session_token": "...", "action_token": { "token": "...", "expires_at": "..." } }
```

---

### Packages

#### `GET /api/v1/packages/inbox`
List packages the user currently holds.

**Response**
```json
{
  "packages": [
    {
      "id": "pkg_...",
      "rarity": "rare",
      "theme": "cosmic",
      "deadline": "2026-04-18T12:34:56Z",
      "hops_count": 12,
      "layers_peeled_here": 0,
      "sender_display": "from Paris"
    }
  ]
}
```

#### `POST /api/v1/packages/{id}/peel`
Peel one layer. Requires signed action. Idempotent by nonce.

**Request headers**
- `X-PEELED-Action` required

**Response (not-final-layer)**
```json
{
  "layer": {
    "type": "mini_reward",
    "content": { "coins": 45 },
    "reveal_copy": "A little something from Tokyo..."
  },
  "package": { "id": "...", "peels_here_remaining": 0, "next_action_required_by": "..." }
}
```
**Response (final layer — WIN)**
```json
{
  "layer": { "type": "final", "content": { "prize": { ... } } },
  "win": {
    "prize_id": "...",
    "rarity": "epic",
    "total_layers": 7,
    "travel_hops": 18,
    "share_card_url": "https://cdn.peeled.app/share/..."
  }
}
```

#### `POST /api/v1/packages/{id}/pass`
Pass to a random recipient.

**Request**
```json
{}
```

#### `POST /api/v1/packages/{id}/send-to-friend`
**Request**
```json
{ "friend_user_id": "..." }
```

#### `POST /api/v1/packages/create`
User-initiated new package (costs PEELED Tokens).

**Request**
```json
{ "rarity": "common", "recipient": "random|friend", "friend_user_id": "..." }
```

---

### Map

#### `GET /api/v1/map/live`
Snapshot of current map state (used on cold-start before WebSocket subscribes).

#### `WS /ws/map`
Realtime stream of `hop` events. See ARCHITECTURE §6.

Message:
```json
{"t": "hop", "pkg": "abc123", "rarity": "epic", "from": {"lat": 48.8, "lng": 2.3}, "to": {"lat": 35.7, "lng": 139.7}, "ts": 1731293409200}
```

---

### Users

- `GET  /api/v1/users/me`
- `PATCH /api/v1/users/me` (username, avatar, notification prefs)
- `GET  /api/v1/users/{id}/public`

---

### Friends

- `GET  /api/v1/friends`
- `POST /api/v1/friends/{user_id}` (follow)
- `DELETE /api/v1/friends/{user_id}`
- `GET  /api/v1/friends/search?q=...`

---

### Leaderboards

- `GET /api/v1/leaderboard/{kind}` where kind in `global_weekly | country_weekly | friends | speed_rare | streaks`

---

### Shop

- `GET  /api/v1/shop/catalog`
- `POST /api/v1/shop/purchase` (server verifies IAP receipt)

---

### Notifications

- `POST /api/v1/notifications/register` (FCM token)
- `PATCH /api/v1/notifications/prefs`

---

### Reports / Safety

- `POST /api/v1/reports` (report a user or package)
- `POST /api/v1/users/{id}/block`

---

## Rate limits (per user)

See ARCHITECTURE §8.3.

## Idempotency

Writes accept `Idempotency-Key` header. Server stores key→response for 24h.
