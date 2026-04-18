"""Auth routes: exchange Supabase JWT for a game session token; mint action tokens."""
from __future__ import annotations

from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends

from app.core.auth import AuthenticatedUser, issue_session_token, require_user, verify_supabase_jwt
from app.core.config import Settings, get_settings
from app.core.rate_limit import check as rate_limit_check
from app.core.signed_action import sign as sign_action
from app.schemas.auth import (
    ActionTokenRequest,
    ActionTokenResponse,
    LoginRequest,
    LoginResponse,
)

router = APIRouter()


@router.post("/login", response_model=LoginResponse)
async def login(
    req: LoginRequest, settings: Settings = Depends(get_settings)
) -> LoginResponse:
    user = verify_supabase_jwt(req.supabase_jwt, settings)
    token, exp = issue_session_token(user.user_id, req.device_id, settings)
    return LoginResponse(session_token=token, expires_at=exp, user_id=user.user_id)


@router.post("/action-token", response_model=ActionTokenResponse)
async def create_action_token(
    req: ActionTokenRequest,
    user: AuthenticatedUser = Depends(require_user),
    settings: Settings = Depends(get_settings),
) -> ActionTokenResponse:
    await rate_limit_check(user.user_id, f"action_token:{req.action}", per_minute=60, per_hour=1200)
    token = sign_action(req.action, user.user_id, req.package_id)
    exp = datetime.now(tz=UTC) + timedelta(seconds=settings.action_token_ttl_seconds)
    return ActionTokenResponse(token=token, expires_at=exp)
