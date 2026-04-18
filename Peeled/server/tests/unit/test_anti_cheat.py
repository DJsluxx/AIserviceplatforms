"""Anti-cheat heuristic tests."""
from __future__ import annotations

import time

import pytest

from app.services.anti_cheat import (
    PeelSignal,
    Verdict,
    analyze_peel,
    is_device_quarantined,
    bump_device_integrity_failure,
)


@pytest.mark.asyncio
async def test_first_peel_clean() -> None:
    report = await analyze_peel(
        PeelSignal(
            user_id="u1",
            package_id="p1",
            device_id="dev1",
            client_ts=time.time(),
            server_ts=time.time(),
            layer_index=0,
        )
    )
    assert report.verdict == Verdict.CLEAN


@pytest.mark.asyncio
async def test_rapid_fire_peels_are_cheating() -> None:
    now = time.time()
    await analyze_peel(
        PeelSignal(
            user_id="bot1", package_id="p1", device_id="dev1",
            client_ts=now, server_ts=now, layer_index=0,
        )
    )
    # immediate follow-up peel (below MIN_PEEL_INTERVAL)
    report = await analyze_peel(
        PeelSignal(
            user_id="bot1", package_id="p1", device_id="dev1",
            client_ts=now + 0.05, server_ts=now + 0.05, layer_index=1,
        )
    )
    assert report.verdict in (Verdict.SUSPICIOUS, Verdict.CHEATING)


@pytest.mark.asyncio
async def test_clock_skew_raises_score() -> None:
    now = time.time()
    report = await analyze_peel(
        PeelSignal(
            user_id="u_skew", package_id="p1", device_id="dev1",
            client_ts=now + 5000, server_ts=now, layer_index=0,
        )
    )
    assert "clock_skew" in "".join(report.reasons) or report.score > 0


@pytest.mark.asyncio
async def test_device_quarantine_after_threshold() -> None:
    for _ in range(5):
        await bump_device_integrity_failure("dev_bad")
    assert await is_device_quarantined("dev_bad", threshold=5)
    assert not await is_device_quarantined("dev_good", threshold=5)
