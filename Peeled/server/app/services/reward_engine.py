"""Reward calculation — XP, coins, tokens for player actions.

Every gameplay action emits a RewardDelta the caller applies to the player
ledger via SQL. All dollar-value prizes go through `final_prize` in the
layer_engine's FINAL layer payload.
"""
from __future__ import annotations

from dataclasses import dataclass

from app.models.enums import LayerType, Rarity


@dataclass(frozen=True, slots=True)
class RewardDelta:
    xp: int = 0
    coins: int = 0
    tokens: int = 0
    streak_hit: bool = False


XP_PER_PEEL = {
    Rarity.COMMON: 2,
    Rarity.UNCOMMON: 4,
    Rarity.RARE: 8,
    Rarity.EPIC: 16,
    Rarity.LEGENDARY: 32,
    Rarity.MYTHIC: 64,
}
XP_FINAL_BONUS = {
    Rarity.COMMON: 10,
    Rarity.UNCOMMON: 25,
    Rarity.RARE: 60,
    Rarity.EPIC: 140,
    Rarity.LEGENDARY: 320,
    Rarity.MYTHIC: 800,
}


def peel_reward(*, rarity: Rarity, layer_type: LayerType, is_final: bool) -> RewardDelta:
    """The reward for peeling one layer."""
    xp = XP_PER_PEEL[rarity]
    coins = 0
    tokens = 0

    if layer_type == LayerType.MINI_REWARD:
        coins += 5 * (list(Rarity).index(rarity) + 1)
    if layer_type == LayerType.FINAL or is_final:
        xp += XP_FINAL_BONUS[rarity]
        coins += 25 * (list(Rarity).index(rarity) + 1)
        if rarity in (Rarity.EPIC, Rarity.LEGENDARY, Rarity.MYTHIC):
            tokens += 1
    return RewardDelta(xp=xp, coins=coins, tokens=tokens, streak_hit=True)


def pass_reward(rarity: Rarity) -> RewardDelta:
    """Small XP for passing a package onward — keeps the network humming."""
    return RewardDelta(xp=max(1, XP_PER_PEEL[rarity] // 2), streak_hit=True)


def send_reward() -> RewardDelta:
    return RewardDelta(xp=3, coins=2, streak_hit=True)


def create_reward() -> RewardDelta:
    return RewardDelta(xp=5, streak_hit=True)
