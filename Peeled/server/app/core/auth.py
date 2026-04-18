"""Authentication: Supabase JWT verification + game session tokens.

Two token layers:
  1. Supabase JWT — carries identity (auth.users.id, email). Verified by shared secret.
  2. Game session token — issued by us after Supabase verify, carries user_id, device_id, scopes.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

import jwt
from fastapi import Depends, HTTPException, Request, status

from app.core.config import Settings, get_settings
from app.core.errors import ApiError


@dataclass(frozen=True, slots=True)
class AuthenticatedUser:
    user_id: str
    device_id: str | None
    is_shadow_banned: bool = False


def _bearer(request: Request) -> str:
    header = request.headers.get("authorization") or request.headers.get("Authorization")
    if not header or not header.lower().startswith("bearer "):
        raise ApiError("UNAUTHENTICATED", "Missing bearer token", status.HTTP_401_UNAUTHORIZED)
    return header.split(" ", 1)[1].strip()


def issue_session_token(
    user_id: str, device_id: str | None, settings: Settings | None = None
) -> tuple[str, datetime]:
    s = settings or get_settings()
    now = datetime.now(tz=UTC)
    exp = now + timedelta(seconds=s.session_ttl_seconds)
    payload = {
        "sub": user_id,
        "device": device_id,
        "iat": int(now.timestamp()),
        "exp": int(exp.timestamp()),
        "kind": "session",
    }
    token = jwt.encode(payload, s.jwt_secret, algorithm=s.jwt_algorithm)
    return token, exp


def verify_session_token(token: str, settings: Settings | None = None) -> AuthenticatedUser:
    s = settings or get_settings()
    try:
        payload = jwt.decode(token, s.jwt_secret, algorithms=[s.jwt_algorithm])
    except jwt.ExpiredSignatureError as e:
        raise ApiError("UNAUTHENTICATED", "Session expired", 401) from e
    except jwt.InvalidTokenError as e:
        raise ApiError("UNAUTHENTICATED", "Invalid session", 401) from e
    if payload.get("kind") != "session":
        raise ApiError("UNAUTHENTICATED", "Wrong token kind", 401)
    return AuthenticatedUser(user_id=str(payload["sub"]), device_id=payload.get("device"))


def verify_supabase_jwt(token: str, settings: Settings | None = None) -> AuthenticatedUser:
    s = settings or get_settings()
    if not s.supabase_jwt_secret:
        # In tests / local dev, allow Supabase JWT to be just our own JWT.
        return verify_session_token(token, s)
    try:
        payload = jwt.decode(
            token,
            s.supabase_jwt_secret,
            algorithms=["HS256"],
            audience="authenticated",
        )
    except jwt.InvalidTokenError as e:
        raise ApiError("UNAUTHENTICATED", "Invalid Supabase token", 401) from e
    return AuthenticatedUser(user_id=str(payload["sub"]), device_id=None)


async def require_user(
    request: Request, settings: Settings = Depends(get_settings)
) -> AuthenticatedUser:
    token = _bearer(request)
    return verify_session_token(token, settings)
