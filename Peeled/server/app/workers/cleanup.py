"""Nightly cleanup — trims old events, audit rows, notification dedupe keys."""
from __future__ import annotations

import asyncio

from sqlalchemy import text

from app.core.database import session_scope
from app.core.logging import configure_logging, get_logger

log = get_logger("peeled.cleanup")
INTERVAL_SECONDS = 3600


async def run_once() -> None:
    async with session_scope() as session:
        await session.execute(
            text("DELETE FROM package_events WHERE created_at < now() - interval '90 days'")
        )
        await session.execute(
            text("DELETE FROM audit_anti_cheat WHERE created_at < now() - interval '30 days'")
        )
        await session.execute(
            text("DELETE FROM notifications_sent WHERE created_at < now() - interval '14 days'")
        )
    log.info("cleanup.done")


async def run_forever() -> None:
    configure_logging()
    while True:
        try:
            await run_once()
        except Exception:  # pragma: no cover
            log.exception("cleanup.error")
        await asyncio.sleep(INTERVAL_SECONDS)


if __name__ == "__main__":  # pragma: no cover
    asyncio.run(run_forever())
