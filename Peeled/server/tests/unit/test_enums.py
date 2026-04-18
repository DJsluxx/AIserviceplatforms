"""Enum + rarity ladder tests."""
from __future__ import annotations

from app.models.enums import RARITY_ORDER, Rarity, downgrade_rarity


def test_downgrade_rarity_steps_down_one() -> None:
    assert downgrade_rarity(Rarity.MYTHIC) == Rarity.LEGENDARY
    assert downgrade_rarity(Rarity.LEGENDARY) == Rarity.EPIC
    assert downgrade_rarity(Rarity.EPIC) == Rarity.RARE
    assert downgrade_rarity(Rarity.RARE) == Rarity.UNCOMMON
    assert downgrade_rarity(Rarity.UNCOMMON) == Rarity.COMMON


def test_downgrade_rarity_floor_is_common() -> None:
    assert downgrade_rarity(Rarity.COMMON) == Rarity.COMMON


def test_rarity_order_complete() -> None:
    assert set(RARITY_ORDER) == set(Rarity)
    assert len(RARITY_ORDER) == 6
