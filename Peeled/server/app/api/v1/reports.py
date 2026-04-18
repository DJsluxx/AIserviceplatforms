"""Report abuse / block routes."""
from __future__ import annotations

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import text

from app.core.auth import AuthenticatedUser, require_user
from app.core.database import session_scope
from app.schemas.common import ApiOk

router = APIRouter()


class ReportRequest(BaseModel):
    target_user_id: str | None = None
    package_id: str | None = None
    reason: str
    detail: str | None = None


@router.post("/", response_model=ApiOk[dict])
async def submit_report(
    req: ReportRequest, user: AuthenticatedUser = Depends(require_user)
) -> ApiOk[dict]:
    async with session_scope() as session:
        await session.execute(
            text(
                """
                INSERT INTO reports
                (reporter_id, target_user_id, package_id, reason, detail, created_at)
                VALUES (:r, :tu, :p, :reason, :detail, now())
                """
            ),
            {
                "r": user.user_id,
                "tu": req.target_user_id,
                "p": req.package_id,
                "reason": req.reason,
                "detail": req.detail,
            },
        )
    return ApiOk(data={"received": True})


class BlockRequest(BaseModel):
    target_user_id: str


@router.post("/block", response_model=ApiOk[dict])
async def block_user(
    req: BlockRequest, user: AuthenticatedUser = Depends(require_user)
) -> ApiOk[dict]:
    async with session_scope() as session:
        await session.execute(
            text(
                """
                INSERT INTO blocks (user_id, blocked_user_id, created_at)
                VALUES (:u, :b, now())
                ON CONFLICT DO NOTHING
                """
            ),
            {"u": user.user_id, "b": req.target_user_id},
        )
    return ApiOk(data={"blocked": True})
