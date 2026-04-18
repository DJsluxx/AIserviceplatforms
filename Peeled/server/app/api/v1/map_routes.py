"""Map routes — snapshot of live packages for the globe."""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import text

from app.core.auth import AuthenticatedUser, require_user
from app.core.database import session_scope
from app.schemas.common import ApiOk
from app.schemas.packages import LiveMapPackage

router = APIRouter()


@router.get("/live", response_model=ApiOk[list[LiveMapPackage]])
async def live(
    limit: int = Query(200, ge=1, le=1000),
    _user: AuthenticatedUser = Depends(require_user),
) -> ApiOk[list[LiveMapPackage]]:
    async with session_scope() as session:
        rows = await session.execute(
            text(
                """
                SELECT id, rarity::text AS rarity,
                    origin_lat, origin_lng, current_lat, current_lng,
                    EXTRACT(EPOCH FROM (now() - updated_at))::int AS t_seconds
                FROM live_packages_public
                WHERE current_lat IS NOT NULL AND origin_lat IS NOT NULL
                ORDER BY updated_at DESC
                LIMIT :lim
                """
            ),
            {"lim": limit},
        )
        out: list[LiveMapPackage] = []
        for r in rows.mappings():
            out.append(
                LiveMapPackage(
                    id=str(r["id"]),
                    rarity=r["rarity"],
                    from_lat=float(r["origin_lat"]),
                    from_lng=float(r["origin_lng"]),
                    to_lat=float(r["current_lat"]),
                    to_lng=float(r["current_lng"]),
                    t_seconds=int(r["t_seconds"]),
                )
            )
    return ApiOk(data=out)
