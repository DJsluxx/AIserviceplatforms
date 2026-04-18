"""Leaderboard routes — Redis ZSET backed."""
from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Literal

from fastapi import APIRouter, Depends, Query
from sqlalchemy import text

from app.core.auth import AuthenticatedUser, require_user
from app.core.database import session_scope
from app.core.redis_client import get_redis
from app.schemas.common import ApiOk
from app.schemas.users import Leaderboard, LeaderboardEntry, UserPublic

router = APIRouter()


def _zkey(kind: str, window: str) -> str:
    return f"lb:{kind}:{window}"


@router.get("/", response_model=ApiOk[Leaderboard])
async def get_leaderboard(
    kind: Literal["peels", "opens", "streak", "friends"] = Query("peels"),
    window: Literal["day", "week", "all"] = Query("week"),
    limit: int = Query(50, ge=1, le=200),
    _user: AuthenticatedUser = Depends(require_user),
) -> ApiOk[Leaderboard]:
    redis = get_redis()
    key = _zkey(kind, window)
    entries_raw = await redis.zrevrange(key, 0, limit - 1, withscores=True)
    if not entries_raw:
        now = datetime.now(tz=UTC)
        return ApiOk(
            data=Leaderboard(
                kind=kind,
                entries=[],
                window_start=now - timedelta(days=7),
                window_end=now,
            )
        )
    ids = [e[0] for e in entries_raw]
    scores = {e[0]: int(e[1]) for e in entries_raw}

    async with session_scope() as session:
        rows = await session.execute(
            text(
                """
                SELECT id, display_name, handle, level, xp, streak_days, country_code
                FROM users_public WHERE id = ANY(:ids)
                """
            ),
            {"ids": ids},
        )
        user_map = {str(r["id"]): UserPublic(**dict(r)) for r in rows.mappings()}

    entries: list[LeaderboardEntry] = []
    for rank, uid in enumerate(ids, start=1):
        u = user_map.get(uid)
        if u:
            entries.append(LeaderboardEntry(rank=rank, user=u, score=scores[uid]))
    now = datetime.now(tz=UTC)
    data = Leaderboard(
        kind=kind,
        entries=entries,
        window_start=now - timedelta(days=7 if window == "week" else 1),
        window_end=now,
    )
    return ApiOk(data=data)
