"""User profile routes."""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import text

from app.core.auth import AuthenticatedUser, require_user
from app.core.database import session_scope
from app.core.errors import ApiError
from app.schemas.common import ApiOk
from app.schemas.users import UpdateProfileRequest, UserPublic

router = APIRouter()


@router.get("/me", response_model=ApiOk[UserPublic])
async def me(user: AuthenticatedUser = Depends(require_user)) -> ApiOk[UserPublic]:
    async with session_scope() as session:
        row = await session.execute(
            text(
                """
                SELECT id, display_name, handle, level, xp, streak_days, country_code
                FROM users WHERE id = :u
                """
            ),
            {"u": user.user_id},
        )
        r = row.mappings().first()
    if not r:
        raise ApiError("USER_NOT_FOUND", "user missing", 404)
    return ApiOk(data=UserPublic(**dict(r)))


@router.patch("/me", response_model=ApiOk[UserPublic])
async def update_me(
    req: UpdateProfileRequest,
    user: AuthenticatedUser = Depends(require_user),
) -> ApiOk[UserPublic]:
    updates: dict[str, str] = {}
    params: dict[str, str] = {"u": user.user_id}
    if req.display_name is not None:
        updates["display_name"] = ":dn"
        params["dn"] = req.display_name
    if req.handle is not None:
        updates["handle"] = ":h"
        params["h"] = req.handle
    if req.country_code is not None:
        updates["country_code"] = ":cc"
        params["cc"] = req.country_code
    if not updates:
        raise ApiError("NO_CHANGES", "nothing to update", 400)
    sets = ", ".join(f"{k} = {v}" for k, v in updates.items())
    async with session_scope() as session:
        await session.execute(
            text(f"UPDATE users SET {sets}, updated_at = now() WHERE id = :u"), params
        )
        row = await session.execute(
            text(
                """
                SELECT id, display_name, handle, level, xp, streak_days, country_code
                FROM users WHERE id = :u
                """
            ),
            {"u": user.user_id},
        )
        r = row.mappings().first()
    assert r is not None
    return ApiOk(data=UserPublic(**dict(r)))


@router.get("/{user_id}", response_model=ApiOk[UserPublic])
async def get_user(
    user_id: str, _user: AuthenticatedUser = Depends(require_user)
) -> ApiOk[UserPublic]:
    async with session_scope() as session:
        row = await session.execute(
            text(
                """
                SELECT id, display_name, handle, level, xp, streak_days, country_code
                FROM users_public WHERE id = :u
                """
            ),
            {"u": user_id},
        )
        r = row.mappings().first()
    if not r:
        raise ApiError("USER_NOT_FOUND", "user missing", 404)
    return ApiOk(data=UserPublic(**dict(r)))
