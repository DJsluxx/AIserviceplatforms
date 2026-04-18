"""Token-bucket rate limiting backed by Redis."""
from __future__ import annotations

from app.core.errors import ApiError
from app.core.redis_client import get_redis


async def check(user_id: str, action: str, per_minute: int, per_hour: int) -> None:
    redis = get_redis()
    min_key = f"rl:{action}:{user_id}:m"
    hr_key = f"rl:{action}:{user_id}:h"

    pipe = redis.pipeline()
    pipe.incr(min_key)
    pipe.expire(min_key, 60, nx=True)
    pipe.incr(hr_key)
    pipe.expire(hr_key, 3600, nx=True)
    minute_count, _, hour_count, _ = await pipe.execute()

    if minute_count > per_minute:
        raise ApiError("RATE_LIMITED", f"too many {action} per minute", 429, {"retry_after": 60})
    if hour_count > per_hour:
        raise ApiError("RATE_LIMITED", f"too many {action} per hour", 429, {"retry_after": 3600})
