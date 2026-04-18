"""Package routes: inbox, peel, pass, send-to-friend, create."""
from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

from fastapi import APIRouter, Depends
from sqlalchemy import text

from app.core.auth import AuthenticatedUser, require_user
from app.core.config import Settings, get_settings
from app.core.database import session_scope
from app.core.errors import ApiError
from app.core.rate_limit import check as rate_limit_check
from app.core.signed_action import consume as consume_action
from app.models.enums import Rarity
from app.schemas.common import ApiOk
from app.schemas.packages import (
    CreatePackageRequest,
    Inbox,
    InboxItem,
    PackageOut,
    PassRequest,
    PeeledLayerOut,
    PeelRequest,
    PeelResponse,
    SendToFriendRequest,
)
from app.services import package_service
from app.services.package_router import Candidate

router = APIRouter()


async def _load_candidates(session: Any, sender_id: str, limit: int = 200) -> list[Candidate]:
    rows = await session.execute(
        text(
            """
            SELECT u.id, EXTRACT(EPOCH FROM COALESCE(u.last_active_at, now() - interval '7 days')) AS last_active,
                   COALESCE(u.streak_days, 0) AS streak_days,
                   u.country_code, u.is_shadow_banned,
                   (SELECT COUNT(*) FROM packages p WHERE p.current_holder_id = u.id
                        AND p.status = 'held') AS active_pkgs,
                   (SELECT COUNT(*) FROM peels pe WHERE pe.user_id = u.id
                        AND pe.server_ts > now() - interval '30 days') AS peels_30d,
                   (SELECT COUNT(*) FROM package_events e WHERE e.actor_id = u.id
                        AND e.event_type = 'received'
                        AND e.created_at > now() - interval '1 hour') AS recv_1h,
                   EXISTS (SELECT 1 FROM friendships f WHERE f.user_a_id = :sender
                        AND f.user_b_id = u.id AND f.status = 'accepted') AS is_friend
            FROM users u
            WHERE u.id <> :sender
              AND COALESCE(u.is_shadow_banned, false) = false
              AND u.last_active_at > now() - interval '3 days'
            ORDER BY u.last_active_at DESC NULLS LAST
            LIMIT :lim
            """
        ),
        {"sender": sender_id, "lim": limit},
    )
    out: list[Candidate] = []
    for r in rows.mappings():
        out.append(
            Candidate(
                user_id=str(r["id"]),
                last_active_ts=float(r["last_active"]),
                recent_peels_30d=int(r["peels_30d"]),
                recent_receives_1h=int(r["recv_1h"]),
                is_friend_of_sender=bool(r["is_friend"]),
                streak_days=int(r["streak_days"]),
                country_code=r["country_code"],
                concurrent_active_packages=int(r["active_pkgs"]),
            )
        )
    return out


@router.get("/inbox", response_model=ApiOk[Inbox])
async def get_inbox(
    user: AuthenticatedUser = Depends(require_user),
    settings: Settings = Depends(get_settings),
) -> ApiOk[Inbox]:
    now = datetime.now(tz=UTC)
    async with session_scope() as session:
        rows = await session.execute(
            text(
                """
                SELECT id, rarity::text AS rarity, status::text AS status, total_layers,
                       peeled_layers, hops, hold_deadline, current_holder_id,
                       origin_lat, origin_lng, current_lat, current_lng, theme, updated_at
                FROM packages
                WHERE current_holder_id = :u AND status = 'held'
                ORDER BY hold_deadline ASC NULLS LAST
                LIMIT :max
                """
            ),
            {"u": user.user_id, "max": settings.max_concurrent_packages_per_user},
        )
        items: list[InboxItem] = []
        for r in rows.mappings():
            deadline: datetime | None = r["hold_deadline"]
            secs = max(0, int((deadline - now).total_seconds())) if deadline else 0
            items.append(
                InboxItem(
                    package=PackageOut(
                        id=str(r["id"]),
                        rarity=Rarity(r["rarity"]),
                        status=r["status"],
                        total_layers=r["total_layers"],
                        peeled_layers=r["peeled_layers"],
                        hops=r["hops"],
                        hold_deadline=deadline,
                        current_holder_id=r["current_holder_id"],
                        origin_lat=r["origin_lat"],
                        origin_lng=r["origin_lng"],
                        current_lat=r["current_lat"],
                        current_lng=r["current_lng"],
                        theme=r["theme"],
                        updated_at=r["updated_at"],
                    ),
                    seconds_remaining=secs,
                )
            )
    data = Inbox(
        items=items,
        concurrent_slots_used=len(items),
        max_concurrent_slots=settings.max_concurrent_packages_per_user,
    )
    return ApiOk(data=data)


@router.post("/{package_id}/peel", response_model=ApiOk[PeelResponse])
async def peel_package(
    package_id: str,
    req: PeelRequest,
    user: AuthenticatedUser = Depends(require_user),
    settings: Settings = Depends(get_settings),
) -> ApiOk[PeelResponse]:
    await rate_limit_check(
        user.user_id,
        "peel",
        per_minute=settings.rate_limit_peels_per_minute,
        per_hour=settings.rate_limit_peels_per_hour,
    )
    await consume_action(
        req.action_token,
        expected_action="peel",
        expected_user_id=user.user_id,
        expected_package_id=package_id,
    )

    outcome = await package_service.peel(
        package_id=package_id,
        user_id=user.user_id,
        device_id=req.device_id,
        client_ts=req.client_ts,
    )

    async with session_scope() as session:
        row = await session.execute(
            text(
                """
                SELECT id, rarity::text AS rarity, status::text AS status, total_layers,
                       peeled_layers, hops, hold_deadline, current_holder_id,
                       origin_lat, origin_lng, current_lat, current_lng, theme, updated_at
                FROM packages WHERE id = :id
                """
            ),
            {"id": package_id},
        )
        r = row.mappings().first()
    if not r:
        raise ApiError("PACKAGE_NOT_FOUND", "package disappeared", 404)
    pkg = PackageOut(
        id=str(r["id"]),
        rarity=Rarity(r["rarity"]),
        status=r["status"],
        total_layers=r["total_layers"],
        peeled_layers=r["peeled_layers"],
        hops=r["hops"],
        hold_deadline=r["hold_deadline"],
        current_holder_id=r["current_holder_id"],
        origin_lat=r["origin_lat"],
        origin_lng=r["origin_lng"],
        current_lat=r["current_lat"],
        current_lng=r["current_lng"],
        theme=r["theme"],
        updated_at=r["updated_at"],
    )
    return ApiOk(
        data=PeelResponse(
            package=pkg,
            revealed=PeeledLayerOut(
                index=outcome.layer_index,
                layer_type=outcome.layer_type,
                payload=outcome.payload,
            ),
            is_final=outcome.is_final,
            reward={"xp": outcome.reward.xp, "coins": outcome.reward.coins,
                    "tokens": outcome.reward.tokens} if outcome.reward else None,
        )
    )


@router.post("/{package_id}/pass", response_model=ApiOk[PackageOut])
async def pass_package_route(
    package_id: str,
    req: PassRequest,
    user: AuthenticatedUser = Depends(require_user),
) -> ApiOk[PackageOut]:
    await rate_limit_check(user.user_id, "pass", per_minute=30, per_hour=300)
    await consume_action(
        req.action_token,
        expected_action="pass",
        expected_user_id=user.user_id,
        expected_package_id=package_id,
    )
    async with session_scope() as session:
        candidates = await _load_candidates(session, user.user_id)
    await package_service.pass_package(
        package_id=package_id, user_id=user.user_id, recipient_candidates=candidates
    )
    async with session_scope() as session:
        row = await session.execute(
            text(
                """
                SELECT id, rarity::text AS rarity, status::text AS status, total_layers,
                       peeled_layers, hops, hold_deadline, current_holder_id,
                       origin_lat, origin_lng, current_lat, current_lng, theme, updated_at
                FROM packages WHERE id = :id
                """
            ),
            {"id": package_id},
        )
        r = row.mappings().first()
    if not r:
        raise ApiError("PACKAGE_NOT_FOUND", "package disappeared", 404)
    pkg = PackageOut(
        id=str(r["id"]),
        rarity=Rarity(r["rarity"]),
        status=r["status"],
        total_layers=r["total_layers"],
        peeled_layers=r["peeled_layers"],
        hops=r["hops"],
        hold_deadline=r["hold_deadline"],
        current_holder_id=r["current_holder_id"],
        origin_lat=r["origin_lat"],
        origin_lng=r["origin_lng"],
        current_lat=r["current_lat"],
        current_lng=r["current_lng"],
        theme=r["theme"],
        updated_at=r["updated_at"],
    )
    return ApiOk(data=pkg)


@router.post("/{package_id}/send-to-friend", response_model=ApiOk[PackageOut])
async def send_to_friend(
    package_id: str,
    req: SendToFriendRequest,
    user: AuthenticatedUser = Depends(require_user),
) -> ApiOk[PackageOut]:
    await rate_limit_check(user.user_id, "send_friend", per_minute=10, per_hour=100)
    await consume_action(
        req.action_token,
        expected_action="send_to_friend",
        expected_user_id=user.user_id,
        expected_package_id=package_id,
    )
    async with session_scope() as session:
        fr = await session.execute(
            text(
                """
                SELECT 1 FROM friendships
                WHERE user_a_id = :u AND user_b_id = :f AND status = 'accepted'
                """
            ),
            {"u": user.user_id, "f": req.friend_user_id},
        )
        if not fr.first():
            raise ApiError("NOT_FRIENDS", "only friends can receive targeted packages", 400)

        cnt = await session.execute(
            text(
                """
                SELECT COUNT(*) FROM packages WHERE current_holder_id = :f AND status = 'held'
                """
            ),
            {"f": req.friend_user_id},
        )
        from app.core.config import get_settings as _gs

        if cnt.scalar_one() >= _gs().max_concurrent_packages_per_user:
            raise ApiError("SLOT_FULL", "friend inbox is full", 400)

        await session.execute(
            text(
                """
                UPDATE packages
                SET current_holder_id = :f, status = 'held', hops = hops + 1,
                    hold_deadline = now() + (:w || ' seconds')::interval,
                    updated_at = now()
                WHERE id = :id AND current_holder_id = :u
                """
            ),
            {
                "f": req.friend_user_id,
                "id": package_id,
                "u": user.user_id,
                "w": _gs().default_peel_window_seconds,
            },
        )
        row = await session.execute(
            text(
                """
                SELECT id, rarity::text AS rarity, status::text AS status, total_layers,
                       peeled_layers, hops, hold_deadline, current_holder_id,
                       origin_lat, origin_lng, current_lat, current_lng, theme, updated_at
                FROM packages WHERE id = :id
                """
            ),
            {"id": package_id},
        )
        r = row.mappings().first()
    assert r is not None
    pkg = PackageOut(
        id=str(r["id"]),
        rarity=Rarity(r["rarity"]),
        status=r["status"],
        total_layers=r["total_layers"],
        peeled_layers=r["peeled_layers"],
        hops=r["hops"],
        hold_deadline=r["hold_deadline"],
        current_holder_id=r["current_holder_id"],
        origin_lat=r["origin_lat"],
        origin_lng=r["origin_lng"],
        current_lat=r["current_lat"],
        current_lng=r["current_lng"],
        theme=r["theme"],
        updated_at=r["updated_at"],
    )
    return ApiOk(data=pkg)


@router.post("/create", response_model=ApiOk[PackageOut])
async def create_package_route(
    req: CreatePackageRequest,
    user: AuthenticatedUser = Depends(require_user),
) -> ApiOk[PackageOut]:
    await rate_limit_check(user.user_id, "create", per_minute=5, per_hour=30)
    await consume_action(
        req.action_token,
        expected_action="create_package",
        expected_user_id=user.user_id,
    )
    created = await package_service.create_package(
        creator_id=user.user_id,
        rarity=Rarity.COMMON,
        theme=req.theme,
        layer_count=req.layer_count,
    )
    async with session_scope() as session:
        row = await session.execute(
            text(
                """
                SELECT id, rarity::text AS rarity, status::text AS status, total_layers,
                       peeled_layers, hops, hold_deadline, current_holder_id,
                       origin_lat, origin_lng, current_lat, current_lng, theme, updated_at
                FROM packages WHERE id = :id
                """
            ),
            {"id": created.id},
        )
        r = row.mappings().first()
    assert r is not None
    pkg = PackageOut(
        id=str(r["id"]),
        rarity=Rarity(r["rarity"]),
        status=r["status"],
        total_layers=r["total_layers"],
        peeled_layers=r["peeled_layers"],
        hops=r["hops"],
        hold_deadline=r["hold_deadline"],
        current_holder_id=r["current_holder_id"],
        origin_lat=r["origin_lat"],
        origin_lng=r["origin_lng"],
        current_lat=r["current_lat"],
        current_lng=r["current_lng"],
        theme=r["theme"],
        updated_at=r["updated_at"],
    )
    return ApiOk(data=pkg)
