"""Action signing — every gameplay write requires a server-signed, single-use token.

Payload layout:
{
  "action": "peel" | "pass" | "send_to_friend" | "create_package",
  "user_id": "...",
  "package_id": "..." (optional, bound to resource when applicable),
  "nonce": "16 url-safe bytes",
  "iat": unix_ts,
  "exp": unix_ts
}

Token format: base64url(json(payload)) + "." + base64url(HMAC-SHA256(payload))

Used-nonce set is Redis-backed. TTL = payload.exp - now.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import secrets
import time
from dataclasses import dataclass
from typing import Any

from app.core.config import get_settings
from app.core.errors import ApiError
from app.core.redis_client import get_redis


@dataclass(frozen=True, slots=True)
class SignedActionPayload:
    action: str
    user_id: str
    package_id: str | None
    nonce: str
    iat: int
    exp: int

    def as_dict(self) -> dict[str, Any]:
        return {
            "action": self.action,
            "user_id": self.user_id,
            "package_id": self.package_id,
            "nonce": self.nonce,
            "iat": self.iat,
            "exp": self.exp,
        }


def _b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def _b64url_decode(s: str) -> bytes:
    padding = "=" * (-len(s) % 4)
    return base64.urlsafe_b64decode(s + padding)


def _hmac(payload_bytes: bytes) -> bytes:
    key = get_settings().anti_cheat_signing_secret.encode()
    return hmac.new(key, payload_bytes, hashlib.sha256).digest()


def sign(
    action: str, user_id: str, package_id: str | None, ttl_seconds: int | None = None
) -> str:
    settings = get_settings()
    now = int(time.time())
    ttl = ttl_seconds or settings.action_token_ttl_seconds
    payload = SignedActionPayload(
        action=action,
        user_id=user_id,
        package_id=package_id,
        nonce=_b64url(secrets.token_bytes(16)),
        iat=now,
        exp=now + ttl,
    )
    body = json.dumps(payload.as_dict(), separators=(",", ":"), sort_keys=True).encode()
    sig = _hmac(body)
    return f"{_b64url(body)}.{_b64url(sig)}"


def parse(token: str) -> SignedActionPayload:
    if "." not in token:
        raise ApiError("ACTION_SIGNATURE_INVALID", "malformed", 400)
    b, s = token.split(".", 1)
    try:
        body = _b64url_decode(b)
        sig = _b64url_decode(s)
    except Exception as e:
        raise ApiError("ACTION_SIGNATURE_INVALID", "decode error", 400) from e
    expected = _hmac(body)
    if not hmac.compare_digest(sig, expected):
        raise ApiError("ACTION_SIGNATURE_INVALID", "bad signature", 400)
    try:
        data = json.loads(body)
        return SignedActionPayload(
            action=data["action"],
            user_id=data["user_id"],
            package_id=data.get("package_id"),
            nonce=data["nonce"],
            iat=int(data["iat"]),
            exp=int(data["exp"]),
        )
    except (KeyError, ValueError) as e:
        raise ApiError("ACTION_SIGNATURE_INVALID", "payload error", 400) from e


async def consume(
    token: str,
    expected_action: str,
    expected_user_id: str,
    expected_package_id: str | None = None,
) -> SignedActionPayload:
    """Validate + consume (single-use) an action token."""
    payload = parse(token)
    now = int(time.time())
    if payload.exp < now:
        raise ApiError("ACTION_SIGNATURE_INVALID", "expired action token", 400)
    if payload.action != expected_action:
        raise ApiError("ACTION_SIGNATURE_INVALID", "action mismatch", 400)
    if payload.user_id != expected_user_id:
        raise ApiError("FORBIDDEN", "token not for this user", 403)
    if expected_package_id and payload.package_id != expected_package_id:
        raise ApiError("FORBIDDEN", "token not for this package", 403)

    redis = get_redis()
    key = f"nonce:{payload.nonce}"
    # Single-use: SETNX and set TTL until exp
    set_ok = await redis.set(key, "1", nx=True, ex=max(1, payload.exp - now))
    if not set_ok:
        raise ApiError("NONCE_REPLAYED", "nonce already used", 400)
    return payload
