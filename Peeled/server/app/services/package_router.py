"""Generic N-package router.

Each live package runs its own stateless state machine. The router chooses the
next recipient for a single package using a weighted-random selection over
online candidates:

- online_recency  (30%)
- activity_level  (20%)
- fairness        (20%)  — invert recent receive count
- friend_affinity (15%)
- geo_proximity   (10%)
- streak_bonus    (5%)

Never hardcoded for 2 packages. Scales to any N.
"""
from __future__ import annotations

import math
import random
import time
from dataclasses import dataclass
from typing import Iterable, Sequence

from app.core.config import get_settings


@dataclass(frozen=True, slots=True)
class Candidate:
    user_id: str
    last_active_ts: float  # epoch seconds
    recent_peels_30d: int
    recent_receives_1h: int
    is_friend_of_sender: bool
    streak_days: int
    country_code: str | None = None
    lat: float | None = None
    lng: float | None = None
    online: bool = True
    is_shadow_banned: bool = False
    concurrent_active_packages: int = 0


@dataclass(frozen=True, slots=True)
class RouteRequest:
    package_id: str
    sender_id: str
    sender_country: str | None
    sender_lat: float | None
    sender_lng: float | None


@dataclass(frozen=True, slots=True)
class RouteDecision:
    recipient_id: str
    score: float
    weights: dict[str, float]


WEIGHTS = {
    "online_recency": 0.30,
    "activity_level": 0.20,
    "fairness": 0.20,
    "friend_affinity": 0.15,
    "geo_proximity": 0.10,
    "streak_bonus": 0.05,
}


def _online_recency(last_active_ts: float, now: float) -> float:
    dt = max(0.0, now - last_active_ts)
    # decay: 1.0 if active in last 60s, ~0.5 after 30min, ~0.1 after 3h
    return math.exp(-dt / 1800.0)


def _activity_level(recent_peels_30d: int) -> float:
    # saturating log: 0 peels = 0, 30 = ~0.5, 300+ = ~1.0
    if recent_peels_30d <= 0:
        return 0.0
    return min(1.0, math.log1p(recent_peels_30d) / math.log1p(300))


def _fairness(recent_receives_1h: int) -> float:
    return 1.0 / (1.0 + recent_receives_1h)


def _friend_affinity(is_friend: bool) -> float:
    return 1.0 if is_friend else 0.2


def _haversine_km(
    lat1: float | None, lng1: float | None, lat2: float | None, lng2: float | None
) -> float | None:
    if None in (lat1, lng1, lat2, lng2):
        return None
    r = 6371.0
    from math import asin, cos, radians, sin, sqrt

    assert lat1 is not None and lng1 is not None and lat2 is not None and lng2 is not None
    dlat = radians(lat2 - lat1)
    dlng = radians(lng2 - lng1)
    a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng / 2) ** 2
    return 2 * r * asin(sqrt(a))


def _geo_proximity(
    sender_lat: float | None,
    sender_lng: float | None,
    c: Candidate,
) -> float:
    dist = _haversine_km(sender_lat, sender_lng, c.lat, c.lng)
    if dist is None:
        return 0.3  # neutral when unknown
    # close (< 500km) = 1.0, antipodal (~20000km) = ~0.05
    return max(0.05, math.exp(-dist / 5000.0))


def _streak_bonus(streak_days: int) -> float:
    return min(1.0, streak_days / 30.0)


def score_candidate(c: Candidate, req: RouteRequest, now: float) -> tuple[float, dict[str, float]]:
    parts = {
        "online_recency": _online_recency(c.last_active_ts, now),
        "activity_level": _activity_level(c.recent_peels_30d),
        "fairness": _fairness(c.recent_receives_1h),
        "friend_affinity": _friend_affinity(c.is_friend_of_sender),
        "geo_proximity": _geo_proximity(req.sender_lat, req.sender_lng, c),
        "streak_bonus": _streak_bonus(c.streak_days),
    }
    total = sum(parts[k] * WEIGHTS[k] for k in WEIGHTS)
    return total, parts


def _eligible(c: Candidate, sender_id: str, max_slots: int) -> bool:
    if c.user_id == sender_id:
        return False
    if c.is_shadow_banned:
        return False
    if not c.online:
        return False
    if c.concurrent_active_packages >= max_slots:
        return False
    return True


def pick_recipient(
    candidates: Iterable[Candidate],
    req: RouteRequest,
    *,
    rng: random.Random | None = None,
    now: float | None = None,
    top_k: int = 16,
) -> RouteDecision | None:
    """Weighted random pick among top-K scored eligible candidates."""
    settings = get_settings()
    max_slots = settings.max_concurrent_packages_per_user
    rng = rng or random.Random()
    now = now or time.time()

    elig = [c for c in candidates if _eligible(c, req.sender_id, max_slots)]
    if not elig:
        return None

    scored: list[tuple[Candidate, float, dict[str, float]]] = []
    for c in elig:
        s, parts = score_candidate(c, req, now)
        scored.append((c, s, parts))
    scored.sort(key=lambda t: t[1], reverse=True)
    pool = scored[:top_k]
    weights = [max(s, 1e-6) for _, s, _ in pool]
    chosen = rng.choices(pool, weights=weights, k=1)[0]
    c, s, parts = chosen
    return RouteDecision(recipient_id=c.user_id, score=s, weights=parts)


def pick_recipients_for_batch(
    requests: Sequence[RouteRequest],
    candidates_by_request: dict[str, Sequence[Candidate]],
    *,
    rng: random.Random | None = None,
) -> dict[str, RouteDecision | None]:
    """Route multiple packages independently — stateless, parallelizable."""
    rng = rng or random.Random()
    now = time.time()
    out: dict[str, RouteDecision | None] = {}
    for req in requests:
        cands = candidates_by_request.get(req.package_id, [])
        out[req.package_id] = pick_recipient(cands, req, rng=rng, now=now)
    return out
