"""Package orchestration — the high-level game flows.

Responsibilities:
  - create_package: build layers, insert package + events, place on a recipient.
  - peel: validate action token, call DB `apply_peel` function, compute reward.
  - pass: release current holder, route next.
  - send_to_friend: deliver directly if friend slot available.
  - tick_expired: the worker entry point for expired-hold repair.

Depends on services/ (router, layer_engine, reward_engine, anti_cheat,
notifications) and core/ (signed_action, database).
"""
from __future__ import annotations

import secrets
import time
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any, Iterable

from sqlalchemy import text

from app.core.database import session_scope
from app.core.errors import ApiError
from app.models.enums import EventType, LayerType, PackageStatus, Rarity, downgrade_rarity
from app.services.anti_cheat import PeelSignal, analyze_peel, should_shadow_bucket
from app.services.layer_engine import generate_layers
from app.services.package_router import Candidate, RouteRequest, pick_recipient
from app.services.reward_engine import RewardDelta, create_reward, pass_reward, peel_reward


@dataclass(frozen=True, slots=True)
class PeelOutcome:
    package_id: str
    new_status: PackageStatus
    layer_index: int
    layer_type: LayerType
    payload: dict[str, Any]
    is_final: bool
    reward: RewardDelta
    new_holder_id: str | None


@dataclass(frozen=True, slots=True)
class CreatedPackage:
    id: str
    rarity: Rarity
    total_layers: int


async def create_package(
    *,
    creator_id: str,
    rarity: Rarity,
    theme: str | None,
    layer_count: int | None = None,
    recipient_id: str | None = None,
) -> CreatedPackage:
    seed = secrets.randbits(63)
    layers = generate_layers(
        rarity=rarity, theme=theme, seed=seed, layer_count=layer_count
    )
    package_id = secrets.token_urlsafe(12)
    now = datetime.now(tz=UTC)

    async with session_scope() as session:
        await session.execute(
            text(
                """
                INSERT INTO packages
                (id, creator_id, current_holder_id, rarity, total_layers, peeled_layers,
                 status, hops, theme, created_at, updated_at)
                VALUES
                (:id, :creator, :holder, :rarity, :total, 0,
                 :status, 0, :theme, :now, :now)
                """
            ),
            {
                "id": package_id,
                "creator": creator_id,
                "holder": recipient_id,
                "rarity": rarity.value,
                "total": len(layers),
                "status": (
                    PackageStatus.HELD.value if recipient_id else PackageStatus.CREATED.value
                ),
                "theme": theme,
                "now": now,
            },
        )
        for layer in layers:
            await session.execute(
                text(
                    """
                    INSERT INTO package_layers (package_id, layer_index, layer_type, payload)
                    VALUES (:pid, :idx, :lt, CAST(:payload AS jsonb))
                    """
                ),
                {
                    "pid": package_id,
                    "idx": layer.index,
                    "lt": layer.layer_type.value,
                    "payload": _to_json(layer.payload),
                },
            )
        await _write_event(
            session,
            package_id=package_id,
            event_type=EventType.CREATED,
            actor_id=creator_id,
            payload={"rarity": rarity.value, "total_layers": len(layers)},
        )

    reward = create_reward()
    await _apply_reward(user_id=creator_id, reward=reward)

    return CreatedPackage(id=package_id, rarity=rarity, total_layers=len(layers))


async def peel(
    *,
    package_id: str,
    user_id: str,
    device_id: str | None,
    client_ts: datetime | None,
) -> PeelOutcome:
    signal = PeelSignal(
        user_id=user_id,
        package_id=package_id,
        device_id=device_id,
        client_ts=client_ts.timestamp() if client_ts else None,
        server_ts=time.time(),
        layer_index=-1,
    )
    report = await analyze_peel(signal)

    async with session_scope() as session:
        row = await session.execute(
            text(
                """
                SELECT apply_peel(:pid, :uid) AS result
                """
            ),
            {"pid": package_id, "uid": user_id},
        )
        raw = row.scalar_one_or_none()
        if raw is None:
            raise ApiError("PACKAGE_NOT_FOUND", "package missing or not yours", 404)
        result = raw if isinstance(raw, dict) else _parse_jsonish(raw)

        if result.get("error"):
            raise ApiError(result["error"], result.get("message", "peel failed"), 400)

        layer_index = int(result["layer_index"])
        layer_type = LayerType(result["layer_type"])
        payload = result["payload"] or {}
        is_final = bool(result["is_final"])
        new_status = PackageStatus(result["new_status"])
        new_holder_id = result.get("new_holder_id")

        await _write_event(
            session,
            package_id=package_id,
            event_type=EventType.PEELED,
            actor_id=user_id,
            payload={"layer_index": layer_index, "layer_type": layer_type.value},
        )
        if is_final:
            await _write_event(
                session,
                package_id=package_id,
                event_type=EventType.OPENED,
                actor_id=user_id,
                payload={"prize": payload.get("prize")},
            )

    if should_shadow_bucket(report):
        await _mark_shadow_banned(user_id)

    rarity = Rarity(result["rarity"])
    reward = peel_reward(rarity=rarity, layer_type=layer_type, is_final=is_final)
    await _apply_reward(user_id=user_id, reward=reward)

    return PeelOutcome(
        package_id=package_id,
        new_status=new_status,
        layer_index=layer_index,
        layer_type=layer_type,
        payload=payload,
        is_final=is_final,
        reward=reward,
        new_holder_id=new_holder_id,
    )


async def pass_package(
    *, package_id: str, user_id: str, recipient_candidates: Iterable[Candidate]
) -> str | None:
    async with session_scope() as session:
        pkg = await _load_package_owned(session, package_id, user_id)
        new_hops = pkg["hops"] + 1
        if new_hops > _get_max_hops():
            await _void_package(session, package_id, reason="hop_limit")
            return None

        new_rarity = pkg["rarity"]
        if new_hops > 0 and new_hops % _get_settings_downgrade_interval() == 0:
            new_rarity = downgrade_rarity(Rarity(pkg["rarity"])).value

        req = RouteRequest(
            package_id=package_id,
            sender_id=user_id,
            sender_country=None,
            sender_lat=None,
            sender_lng=None,
        )
        decision = pick_recipient(recipient_candidates, req)
        if decision is None:
            # no recipient available — mark in-flight so ticker retries
            await session.execute(
                text(
                    """
                    UPDATE packages
                    SET status = :s, current_holder_id = NULL, hops = :h, rarity = :r,
                        hold_deadline = NULL, updated_at = now()
                    WHERE id = :id
                    """
                ),
                {
                    "s": PackageStatus.IN_FLIGHT.value,
                    "h": new_hops,
                    "r": new_rarity,
                    "id": package_id,
                },
            )
            await _write_event(
                session, package_id=package_id, event_type=EventType.PASSED,
                actor_id=user_id, payload={"routed": False},
            )
            return None

        await session.execute(
            text(
                """
                UPDATE packages
                SET status = :s, current_holder_id = :h, hops = :hh, rarity = :r,
                    hold_deadline = now() + (:w || ' seconds')::interval,
                    updated_at = now()
                WHERE id = :id
                """
            ),
            {
                "s": PackageStatus.HELD.value,
                "h": decision.recipient_id,
                "hh": new_hops,
                "r": new_rarity,
                "w": _get_peel_window_seconds(),
                "id": package_id,
            },
        )
        await _write_event(
            session, package_id=package_id, event_type=EventType.PASSED,
            actor_id=user_id, payload={"recipient": decision.recipient_id},
        )
        await _write_event(
            session, package_id=package_id, event_type=EventType.ROUTED,
            actor_id=None, payload={"recipient": decision.recipient_id},
        )

    await _apply_reward(user_id=user_id, reward=pass_reward(Rarity(pkg["rarity"])))
    return decision.recipient_id


def _to_json(obj: dict[str, Any]) -> str:
    import json

    return json.dumps(obj, separators=(",", ":"))


def _parse_jsonish(raw: Any) -> dict[str, Any]:
    import json

    if isinstance(raw, (bytes, str)):
        return json.loads(raw)
    return dict(raw)


async def _write_event(
    session: Any, *, package_id: str, event_type: EventType, actor_id: str | None,
    payload: dict[str, Any] | None = None,
) -> None:
    await session.execute(
        text(
            """
            INSERT INTO package_events (id, package_id, event_type, actor_id, created_at, payload)
            VALUES (:id, :pid, :et, :actor, now(), CAST(:payload AS jsonb))
            """
        ),
        {
            "id": secrets.token_urlsafe(12),
            "pid": package_id,
            "et": event_type.value,
            "actor": actor_id,
            "payload": _to_json(payload or {}),
        },
    )


async def _load_package_owned(session: Any, package_id: str, user_id: str) -> dict[str, Any]:
    row = await session.execute(
        text(
            """
            SELECT id, rarity::text AS rarity, hops, status::text AS status
            FROM packages WHERE id = :id AND current_holder_id = :u
            """
        ),
        {"id": package_id, "u": user_id},
    )
    r = row.mappings().first()
    if not r:
        raise ApiError("PACKAGE_NOT_FOUND", "package missing or not yours", 404)
    return dict(r)


async def _void_package(session: Any, package_id: str, *, reason: str) -> None:
    await session.execute(
        text(
            """
            UPDATE packages SET status = :s, current_holder_id = NULL,
                hold_deadline = NULL, updated_at = now()
            WHERE id = :id
            """
        ),
        {"s": PackageStatus.VOIDED.value, "id": package_id},
    )
    await _write_event(
        session, package_id=package_id, event_type=EventType.VOIDED,
        actor_id=None, payload={"reason": reason},
    )


async def _apply_reward(*, user_id: str, reward: RewardDelta) -> None:
    if reward.xp == 0 and reward.coins == 0 and reward.tokens == 0:
        return
    async with session_scope() as session:
        await session.execute(
            text(
                """
                UPDATE users
                SET xp = xp + :xp, last_active_at = now(), updated_at = now()
                WHERE id = :uid
                """
            ),
            {"xp": reward.xp, "uid": user_id},
        )
        if reward.coins or reward.tokens:
            await session.execute(
                text(
                    """
                    INSERT INTO inventory_items (user_id, coins, tokens, updated_at)
                    VALUES (:uid, :c, :t, now())
                    ON CONFLICT (user_id) DO UPDATE SET
                      coins = inventory_items.coins + EXCLUDED.coins,
                      tokens = inventory_items.tokens + EXCLUDED.tokens,
                      updated_at = now()
                    """
                ),
                {"uid": user_id, "c": reward.coins, "t": reward.tokens},
            )
        if reward.streak_hit:
            await session.execute(
                text("SELECT update_streak(:uid)"), {"uid": user_id}
            )


async def _mark_shadow_banned(user_id: str) -> None:
    async with session_scope() as session:
        await session.execute(
            text("UPDATE users SET is_shadow_banned = true WHERE id = :uid"),
            {"uid": user_id},
        )


def _get_peel_window_seconds() -> int:
    from app.core.config import get_settings

    return get_settings().default_peel_window_seconds


def _get_max_hops() -> int:
    from app.core.config import get_settings

    return get_settings().max_hops_before_void


def _get_settings_downgrade_interval() -> int:
    from app.core.config import get_settings

    return get_settings().max_hops_before_rarity_downgrade
