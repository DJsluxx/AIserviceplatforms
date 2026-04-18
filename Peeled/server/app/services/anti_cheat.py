"""Anti-cheat heuristics and signals.

- Impossible-speed peel detection (consecutive peels faster than human reaction).
- Cross-device replay detection.
- Emulator / device-integrity attestation hooks.
- Shadow-bucket assignment (bad actor is routed only to other bad actors).

This module only reports verdicts; enforcement (shadow-ban, void package)
is handled by callers.
"""
from __future__ import annotations

import time
from dataclasses import dataclass, field
from enum import Enum

from app.core.redis_client import get_redis


class Verdict(str, Enum):
    CLEAN = "clean"
    SUSPICIOUS = "suspicious"
    CHEATING = "cheating"


@dataclass(frozen=True, slots=True)
class PeelSignal:
    user_id: str
    package_id: str
    device_id: str | None
    client_ts: float | None
    server_ts: float
    layer_index: int


@dataclass(slots=True)
class HeuristicReport:
    verdict: Verdict = Verdict.CLEAN
    reasons: list[str] = field(default_factory=list)
    score: float = 0.0


MIN_PEEL_INTERVAL_SECONDS = 0.25  # below = bot-like
MAX_CLOCK_SKEW_SECONDS = 120
SUSPICION_THRESHOLD = 0.5
CHEAT_THRESHOLD = 0.85


async def record_peel_timing(user_id: str, server_ts: float) -> float:
    """Return delta since last peel by this user (seconds)."""
    redis = get_redis()
    key = f"ac:last_peel:{user_id}"
    prev = await redis.get(key)
    await redis.set(key, str(server_ts), ex=3600)
    if prev is None:
        return 10_000.0  # large enough
    try:
        return max(0.0, server_ts - float(prev))
    except ValueError:
        return 10_000.0


async def analyze_peel(signal: PeelSignal) -> HeuristicReport:
    rep = HeuristicReport()

    delta = await record_peel_timing(signal.user_id, signal.server_ts)
    if delta < MIN_PEEL_INTERVAL_SECONDS:
        rep.score += 0.5
        rep.reasons.append(f"peel_interval_{delta:.3f}s")

    if signal.client_ts is not None:
        skew = abs(signal.client_ts - signal.server_ts)
        if skew > MAX_CLOCK_SKEW_SECONDS:
            rep.score += 0.2
            rep.reasons.append(f"clock_skew_{int(skew)}s")

    if signal.device_id is None:
        rep.score += 0.1
        rep.reasons.append("no_device_id")

    if rep.score >= CHEAT_THRESHOLD:
        rep.verdict = Verdict.CHEATING
    elif rep.score >= SUSPICION_THRESHOLD:
        rep.verdict = Verdict.SUSPICIOUS
    return rep


async def bump_device_integrity_failure(device_id: str) -> int:
    redis = get_redis()
    key = f"ac:dev_fail:{device_id}"
    n = await redis.incr(key)
    if n == 1:
        await redis.expire(key, 86400)
    return int(n)


async def is_device_quarantined(device_id: str, threshold: int = 5) -> bool:
    redis = get_redis()
    val = await redis.get(f"ac:dev_fail:{device_id}")
    try:
        return int(val or 0) >= threshold
    except (TypeError, ValueError):
        return False


async def seen_nonce(nonce: str) -> bool:
    redis = get_redis()
    key = f"ac:nonce_seen:{nonce}"
    if await redis.exists(key):
        return True
    await redis.set(key, "1", ex=3600)
    return False


def should_shadow_bucket(report: HeuristicReport) -> bool:
    return report.verdict == Verdict.CHEATING


def now() -> float:
    return time.time()
