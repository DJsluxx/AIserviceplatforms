"""Rebuilds leaderboard ZSETs from Postgres snapshots (every 60s)."""
from __future__ import annotations

import asyncio

from sqlalchemy import text

from app.core.database import session_scope
from app.core.logging import configure_logging, get_logger
from app.core.redis_client import get_redis

log = get_logger("peeled.lb")
REFRESH_SECONDS = 60


async def refresh() -> None:
    redis = get_redis()
    async with session_scope() as session:
        # peels / day
        rows = await session.execute(
            text(
                """
                SELECT user_id, COUNT(*)::int AS n
                FROM peels
                WHERE server_ts > now() - interval '1 day'
                GROUP BY user_id
                ORDER BY n DESC
                LIMIT 500
                """
            )
        )
        mapping = {str(r["user_id"]): int(r["n"]) for r in rows.mappings()}
    pipe = redis.pipeline()
    pipe.delete("lb:peels:day")
    for uid, score in mapping.items():
        pipe.zadd("lb:peels:day", {uid: score})
    await pipe.execute()
    log.info("lb.refreshed", count=len(mapping))


async def run_forever() -> None:
    configure_logging()
    log.info("lb.start")
    while True:
        try:
            await refresh()
        except Exception:  # pragma: no cover
            log.exception("lb.error")
        await asyncio.sleep(REFRESH_SECONDS)


if __name__ == "__main__":  # pragma: no cover
    asyncio.run(run_forever())
