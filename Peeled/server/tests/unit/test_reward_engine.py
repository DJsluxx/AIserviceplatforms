"""Reward engine unit tests."""
from __future__ import annotations

import pytest

from app.models.enums import LayerType, Rarity
from app.services.reward_engine import (
    XP_FINAL_BONUS,
    XP_PER_PEEL,
    create_reward,
    pass_reward,
    peel_reward,
    send_reward,
)


@pytest.mark.parametrize("rarity", list(Rarity))
def test_peel_xp_matches_table(rarity: Rarity) -> None:
    r = peel_reward(rarity=rarity, layer_type=LayerType.HINT, is_final=False)
    assert r.xp == XP_PER_PEEL[rarity]
    assert r.streak_hit is True


def test_final_layer_gives_bonus() -> None:
    r = peel_reward(rarity=Rarity.MYTHIC, layer_type=LayerType.FINAL, is_final=True)
    assert r.xp == XP_PER_PEEL[Rarity.MYTHIC] + XP_FINAL_BONUS[Rarity.MYTHIC]
    assert r.tokens >= 1
    assert r.coins > 0


def test_mini_reward_layer_grants_coins() -> None:
    r = peel_reward(rarity=Rarity.RARE, layer_type=LayerType.MINI_REWARD, is_final=False)
    assert r.coins > 0


def test_pass_reward_small() -> None:
    r = pass_reward(Rarity.COMMON)
    assert r.xp >= 1
    assert r.coins == 0


def test_send_and_create_rewards_nonzero() -> None:
    assert send_reward().xp > 0
    assert create_reward().xp > 0
