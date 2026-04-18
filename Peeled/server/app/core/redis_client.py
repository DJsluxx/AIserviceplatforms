"""Redis client singleton. Supports fakeredis in tests."""
from __future__ import annotations

import redis.asyncio as redis_async

from app.core.config import get_settings

_client: redis_async.Redis | None = None


def get_redis() -> redis_async.Redis:
    global _client
    if _client is None:
        settings = get_settings()
        if settings.is_test:
            # Use fakeredis for tests if available
            try:
                import fakeredis.aioredis as fakeredis

                _client = fakeredis.FakeRedis(decode_responses=True)
            except ImportError:
                _client = redis_async.from_url(settings.redis_url, decode_responses=True)
        else:
            _client = redis_async.from_url(settings.redis_url, decode_responses=True)
    return _client


async def close_redis() -> None:
    global _client
    if _client is not None:
        await _client.close()
        _client = None
