"""Package router unit tests — verifies the generic N-package routing logic."""
from __future__ import annotations

import random
import time

import pytest

from app.services.package_router import (
    Candidate,
    RouteRequest,
    pick_recipient,
    pick_recipients_for_batch,
    score_candidate,
)


def _now() -> float:
    return time.time()


def _online_active_candidate(user_id: str, **overrides: object) -> Candidate:
    defaults: dict[str, object] = dict(
        user_id=user_id,
        last_active_ts=_now(),
        recent_peels_30d=50,
        recent_receives_1h=0,
        is_friend_of_sender=False,
        streak_days=3,
        country_code="US",
        online=True,
        is_shadow_banned=False,
        concurrent_active_packages=0,
    )
    defaults.update(overrides)
    return Candidate(**defaults)  # type: ignore[arg-type]


def _req(sender_id: str = "sender1") -> RouteRequest:
    return RouteRequest(
        package_id="pkg1",
        sender_id=sender_id,
        sender_country="US",
        sender_lat=None,
        sender_lng=None,
    )


def test_skips_sender_themselves() -> None:
    cand = _online_active_candidate("sender1")
    d = pick_recipient([cand], _req("sender1"), rng=random.Random(1))
    assert d is None


def test_skips_shadow_banned() -> None:
    c = _online_active_candidate("u1", is_shadow_banned=True)
    assert pick_recipient([c], _req(), rng=random.Random(1)) is None


def test_skips_offline() -> None:
    c = _online_active_candidate("u1", online=False)
    assert pick_recipient([c], _req(), rng=random.Random(1)) is None


def test_skips_at_max_slots() -> None:
    c = _online_active_candidate("u1", concurrent_active_packages=10)
    assert pick_recipient([c], _req(), rng=random.Random(1)) is None


def test_picks_single_eligible_candidate() -> None:
    c = _online_active_candidate("u1")
    d = pick_recipient([c], _req(), rng=random.Random(1))
    assert d is not None
    assert d.recipient_id == "u1"


def test_online_recency_beats_stale() -> None:
    fresh = _online_active_candidate("fresh", last_active_ts=_now())
    stale = _online_active_candidate("stale", last_active_ts=_now() - 7200)
    s_fresh, _ = score_candidate(fresh, _req(), _now())
    s_stale, _ = score_candidate(stale, _req(), _now())
    assert s_fresh > s_stale


def test_friend_affinity_boosts_score() -> None:
    a = _online_active_candidate("a", is_friend_of_sender=False)
    b = _online_active_candidate("b", is_friend_of_sender=True)
    sa, _ = score_candidate(a, _req(), _now())
    sb, _ = score_candidate(b, _req(), _now())
    assert sb > sa


def test_fairness_penalty_for_recent_receives() -> None:
    low = _online_active_candidate("low", recent_receives_1h=0)
    high = _online_active_candidate("high", recent_receives_1h=8)
    sl, _ = score_candidate(low, _req(), _now())
    sh, _ = score_candidate(high, _req(), _now())
    assert sl > sh


@pytest.mark.parametrize("n_packages", [1, 3, 5, 20])
def test_scales_to_n_packages(n_packages: int) -> None:
    """Regression test: the router must never be hardcoded for N=2."""
    candidates = {
        f"p{i}": [_online_active_candidate(f"u{j}") for j in range(n_packages * 3)]
        for i in range(n_packages)
    }
    reqs = [
        RouteRequest(package_id=f"p{i}", sender_id="sender", sender_country="US",
                     sender_lat=None, sender_lng=None)
        for i in range(n_packages)
    ]
    out = pick_recipients_for_batch(reqs, candidates, rng=random.Random(42))
    assert len(out) == n_packages
    assert all(d is not None for d in out.values())


def test_batch_routing_independent_decisions() -> None:
    cands = [_online_active_candidate(f"u{i}") for i in range(10)]
    reqs = [
        RouteRequest(package_id=f"p{i}", sender_id="s", sender_country=None,
                     sender_lat=None, sender_lng=None)
        for i in range(3)
    ]
    out = pick_recipients_for_batch(
        reqs, {r.package_id: cands for r in reqs}, rng=random.Random(123)
    )
    assert set(out.keys()) == {"p0", "p1", "p2"}
