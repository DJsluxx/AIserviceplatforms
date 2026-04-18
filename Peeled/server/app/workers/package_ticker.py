"""Package ticker — polls for expired holds every 500ms and re-routes.

Runs as its own process (uvicorn sidecar). It queries packages whose
hold_deadline is in the past and either:
  - reroutes to a new recipient if one is available,
  - voids if hops exceed cap.

Uses DB advisory locks so multiple ticker replicas don't double-process.
"""
from __future__ import annotations

import asyncio
from datetime import UTC, datetime

from sqlalchemy import text

from app.core.database import session_scope
from app.core.logging import configure_logging, get_logger
from app.models.enums import EventType, PackageStatus, Rarity, downgrade_rarity
from app.services.package_router import Candidate, RouteRequest, pick_recipient

log = get_logger("peeled.ticker")

POLL_INTERVAL_SECONDS = 0.5
BATCH_SIZE = 200
TICKER_LOCK_KEY = 7001  # fixed pg_advisory_xact_lock id


async def _load_candidates(session: object, sender_id: str, limit: int) -> list[Candidate]:
    rows = await session.execute(  # type: ignore[attr-defined]
        text(
            """
            SELECT u.id, EXTRACT(EPOCH FROM COALESCE(u.last_active_at, now() - interval '7 days')) AS last_active,
                   COALESCE(u.streak_days, 0) AS streak_days,
                   u.country_code, u.is_shadow_banned,
                   (SELECT COUNT(*) FROM packages p WHERE p.current_holder_id = u.id
                        AND p.status = 'held') AS active_pkgs,
                   0 AS peels_30d,
                   0 AS recv_1h,
                   false AS is_friend
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


async def _tick_once() -> int:
    async with session_scope() as session:
        got = await session.execute(
            text("SELECT pg_try_advisory_xact_lock(:k) AS ok"),
            {"k": TICKER_LOCK_KEY},
        )
        if not got.scalar_one():
            return 0

        rows = await session.execute(
            text(
                """
                SELECT id, rarity::text AS rarity, current_holder_id, hops
                FROM packages
                WHERE status = 'held' AND hold_deadline < now()
                ORDER BY hold_deadline ASC
                LIMIT :lim
                FOR UPDATE SKIP LOCKED
                """
            ),
            {"lim": BATCH_SIZE},
        )
        expired = list(rows.mappings())
        if not expired:
            return 0

        processed = 0
        from app.core.config import get_settings

        settings = get_settings()
        for r in expired:
            pkg_id = str(r["id"])
            sender_id = r["current_holder_id"]
            hops = int(r["hops"]) + 1
            rarity = Rarity(r["rarity"])
            new_rarity = rarity
            if hops > 0 and hops % settings.max_hops_before_rarity_downgrade == 0:
                new_rarity = downgrade_rarity(rarity)

            if hops > settings.max_hops_before_void:
                await session.execute(
                    text(
                        """
                        UPDATE packages SET status = :s, current_holder_id = NULL,
                            hold_deadline = NULL, updated_at = now()
                        WHERE id = :id
                        """
                    ),
                    {"s": PackageStatus.VOIDED.value, "id": pkg_id},
                )
                await _event(session, pkg_id, EventType.VOIDED, None, {"reason": "hop_limit"})
                processed += 1
                continue

            cands = await _load_candidates(session, sender_id, limit=200)
            decision = pick_recipient(
                cands, RouteRequest(
                    package_id=pkg_id, sender_id=sender_id, sender_country=None,
                    sender_lat=None, sender_lng=None,
                ),
            )

            if decision is None:
                await session.execute(
                    text(
                        """
                        UPDATE packages
                        SET status = :s, current_holder_id = NULL, hops = :h,
                            rarity = :r, hold_deadline = NULL, updated_at = now()
                        WHERE id = :id
                        """
                    ),
                    {
                        "s": PackageStatus.IN_FLIGHT.value,
                        "h": hops,
                        "r": new_rarity.value,
                        "id": pkg_id,
                    },
                )
                await _event(session, pkg_id, EventType.EXPIRED, sender_id, {"reason": "no_candidate"})
            else:
                await session.execute(
                    text(
                        """
                        UPDATE packages
                        SET status = :s, current_holder_id = :h, hops = :hh,
                            rarity = :r,
                            hold_deadline = now() + (:w || ' seconds')::interval,
                            updated_at = now()
                        WHERE id = :id
                        """
                    ),
                    {
                        "s": PackageStatus.HELD.value,
                        "h": decision.recipient_id,
                        "hh": hops,
                        "r": new_rarity.value,
                        "w": settings.default_peel_window_seconds,
                        "id": pkg_id,
                    },
                )
                await _event(session, pkg_id, EventType.EXPIRED, sender_id, {"rerouted_to": decision.recipient_id})
                await _event(session, pkg_id, EventType.ROUTED, None, {"recipient": decision.recipient_id})
            processed += 1
        return processed


async def _event(session: object, pkg_id: str, et: EventType,
                 actor: str | None, payload: dict[str, object]) -> None:
    import json
    import secrets as s

    await session.execute(  # type: ignore[attr-defined]
        text(
            """
            INSERT INTO package_events (id, package_id, event_type, actor_id, created_at, payload)
            VALUES (:id, :pid, :et, :actor, now(), CAST(:payload AS jsonb))
            """
        ),
        {
            "id": s.token_urlsafe(12),
            "pid": pkg_id,
            "et": et.value,
            "actor": actor,
            "payload": json.dumps(payload),
        },
    )


async def run_forever() -> None:
    configure_logging()
    log.info("ticker.start", interval_s=POLL_INTERVAL_SECONDS)
    while True:
        try:
            n = await _tick_once()
            if n:
                log.info("ticker.processed", count=n, ts=datetime.now(tz=UTC).isoformat())
        except Exception:  # pragma: no cover
            log.exception("ticker.error")
        await asyncio.sleep(POLL_INTERVAL_SECONDS)


if __name__ == "__main__":  # pragma: no cover
    asyncio.run(run_forever())
