"""Enums mirroring DB enums in migrations/0001_init.sql."""
from __future__ import annotations

from enum import Enum


class Rarity(str, Enum):
    COMMON = "common"
    UNCOMMON = "uncommon"
    RARE = "rare"
    EPIC = "epic"
    LEGENDARY = "legendary"
    MYTHIC = "mythic"


class PackageStatus(str, Enum):
    CREATED = "created"
    IN_FLIGHT = "in_flight"
    HELD = "held"
    OPENED = "opened"
    EXPIRED = "expired"
    VOIDED = "voided"


class LayerType(str, Enum):
    HINT = "hint"
    MINI_REWARD = "mini_reward"
    POWERUP = "powerup"
    TRAP = "trap"
    FINAL = "final"


class EventType(str, Enum):
    CREATED = "created"
    ROUTED = "routed"
    RECEIVED = "received"
    PEELED = "peeled"
    PASSED = "passed"
    EXPIRED = "expired"
    OPENED = "opened"
    VOIDED = "voided"
    REPORTED = "reported"


RARITY_ORDER = [
    Rarity.COMMON,
    Rarity.UNCOMMON,
    Rarity.RARE,
    Rarity.EPIC,
    Rarity.LEGENDARY,
    Rarity.MYTHIC,
]


def downgrade_rarity(rarity: Rarity) -> Rarity:
    idx = RARITY_ORDER.index(rarity)
    return RARITY_ORDER[max(0, idx - 1)]
