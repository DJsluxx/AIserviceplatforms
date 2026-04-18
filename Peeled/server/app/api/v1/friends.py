"""Friend routes."""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import text

from app.core.auth import AuthenticatedUser, require_user
from app.core.database import session_scope
from app.schemas.common import ApiOk
from app.schemas.users import FriendRequest, UserPublic

router = APIRouter()


@router.post("/request", response_model=ApiOk[dict])
async def send_request(
    req: FriendRequest, user: AuthenticatedUser = Depends(require_user)
) -> ApiOk[dict]:
    async with session_scope() as session:
        await session.execute(
            text(
                """
                INSERT INTO friendships (user_a_id, user_b_id, status, created_at)
                VALUES (:a, :b, 'pending', now())
                ON CONFLICT (user_a_id, user_b_id) DO NOTHING
                """
            ),
            {"a": user.user_id, "b": req.target_user_id},
        )
    return ApiOk(data={"sent": True})


@router.post("/{user_id}/accept", response_model=ApiOk[dict])
async def accept(user_id: str, user: AuthenticatedUser = Depends(require_user)) -> ApiOk[dict]:
    async with session_scope() as session:
        await session.execute(
            text(
                """
                UPDATE friendships SET status = 'accepted'
                WHERE user_a_id = :a AND user_b_id = :b
                """
            ),
            {"a": user_id, "b": user.user_id},
        )
        await session.execute(
            text(
                """
                INSERT INTO friendships (user_a_id, user_b_id, status, created_at)
                VALUES (:a, :b, 'accepted', now())
                ON CONFLICT (user_a_id, user_b_id) DO UPDATE SET status = 'accepted'
                """
            ),
            {"a": user.user_id, "b": user_id},
        )
    return ApiOk(data={"accepted": True})


@router.get("/", response_model=ApiOk[list[UserPublic]])
async def list_friends(
    user: AuthenticatedUser = Depends(require_user),
) -> ApiOk[list[UserPublic]]:
    async with session_scope() as session:
        rows = await session.execute(
            text(
                """
                SELECT u.id, u.display_name, u.handle, u.level, u.xp, u.streak_days, u.country_code
                FROM friendships f JOIN users_public u ON u.id = f.user_b_id
                WHERE f.user_a_id = :u AND f.status = 'accepted'
                ORDER BY u.display_name ASC
                """
            ),
            {"u": user.user_id},
        )
        out = [UserPublic(**dict(r)) for r in rows.mappings()]
    return ApiOk(data=out)
