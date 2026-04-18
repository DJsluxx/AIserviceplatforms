"""Layer generation — deterministic per package.

Given a Package rarity, produce the ordered list of layer payloads. The layer
count scales with rarity, and each layer is one of HINT / MINI_REWARD / POWERUP
/ TRAP / FINAL. The FINAL layer is always last.

Layer payloads:
- HINT: {"text": str} — a breadcrumb toward the prize theme.
- MINI_REWARD: {"kind": "coins"|"xp"|"token", "amount": int}
- POWERUP: {"kind": "skip_ad"|"timer_freeze"|"double_xp", "duration_s": int}
- TRAP: {"kind": "lock_out"|"skip_turn", "severity": int}
- FINAL: {"prize": {"kind": str, "label": str, "value_usd": int|None, "meta": {...}}}
"""
from __future__ import annotations

import random
from dataclasses import dataclass
from typing import Any

from app.models.enums import LayerType, Rarity

LAYER_COUNT_BY_RARITY: dict[Rarity, tuple[int, int]] = {
    Rarity.COMMON: (5, 8),
    Rarity.UNCOMMON: (7, 10),
    Rarity.RARE: (10, 14),
    Rarity.EPIC: (14, 18),
    Rarity.LEGENDARY: (18, 24),
    Rarity.MYTHIC: (24, 30),
}

# Non-final layer weight distribution by rarity.
LAYER_MIX: dict[Rarity, dict[LayerType, float]] = {
    Rarity.COMMON: {
        LayerType.HINT: 0.55,
        LayerType.MINI_REWARD: 0.3,
        LayerType.POWERUP: 0.05,
        LayerType.TRAP: 0.1,
    },
    Rarity.UNCOMMON: {
        LayerType.HINT: 0.5,
        LayerType.MINI_REWARD: 0.32,
        LayerType.POWERUP: 0.08,
        LayerType.TRAP: 0.1,
    },
    Rarity.RARE: {
        LayerType.HINT: 0.45,
        LayerType.MINI_REWARD: 0.32,
        LayerType.POWERUP: 0.12,
        LayerType.TRAP: 0.11,
    },
    Rarity.EPIC: {
        LayerType.HINT: 0.42,
        LayerType.MINI_REWARD: 0.3,
        LayerType.POWERUP: 0.15,
        LayerType.TRAP: 0.13,
    },
    Rarity.LEGENDARY: {
        LayerType.HINT: 0.4,
        LayerType.MINI_REWARD: 0.28,
        LayerType.POWERUP: 0.18,
        LayerType.TRAP: 0.14,
    },
    Rarity.MYTHIC: {
        LayerType.HINT: 0.38,
        LayerType.MINI_REWARD: 0.26,
        LayerType.POWERUP: 0.22,
        LayerType.TRAP: 0.14,
    },
}


@dataclass(frozen=True, slots=True)
class GeneratedLayer:
    index: int
    layer_type: LayerType
    payload: dict[str, Any]


def _pick_weighted(weights: dict[LayerType, float], rng: random.Random) -> LayerType:
    items = list(weights.items())
    r = rng.random() * sum(w for _, w in items)
    upto = 0.0
    for lt, w in items:
        upto += w
        if r <= upto:
            return lt
    return items[-1][0]


def _hint_payload(rng: random.Random, theme: str | None) -> dict[str, Any]:
    pool = [
        "It started somewhere cold.",
        "Follow the color gold.",
        "You'll know it when it rings.",
        "Ancient hands folded it first.",
        "Three of them travel together.",
        "Whisper its name underwater.",
        "The map lies in the last layer.",
        "Keep peeling — patience has weight.",
        "Not everyone is meant to open this.",
        "Count the ribbons. One is false.",
    ]
    text = rng.choice(pool)
    if theme:
        text = f"{text} (theme: {theme})"
    return {"text": text}


def _mini_reward_payload(rng: random.Random, rarity: Rarity) -> dict[str, Any]:
    base = {
        Rarity.COMMON: 5,
        Rarity.UNCOMMON: 10,
        Rarity.RARE: 20,
        Rarity.EPIC: 40,
        Rarity.LEGENDARY: 80,
        Rarity.MYTHIC: 150,
    }[rarity]
    kind = rng.choices(["coins", "xp", "token"], weights=[5, 3, 1], k=1)[0]
    amount = max(1, int(base * rng.uniform(0.5, 1.5)))
    return {"kind": kind, "amount": amount}


def _powerup_payload(rng: random.Random) -> dict[str, Any]:
    kind = rng.choice(["skip_ad", "timer_freeze", "double_xp"])
    duration = rng.choice([30, 60, 120, 300])
    return {"kind": kind, "duration_s": duration}


def _trap_payload(rng: random.Random) -> dict[str, Any]:
    return {
        "kind": rng.choice(["skip_turn", "lock_out"]),
        "severity": rng.randint(1, 3),
    }


def _final_payload(rng: random.Random, rarity: Rarity, theme: str | None) -> dict[str, Any]:
    value_by_rarity = {
        Rarity.COMMON: (0, 1),
        Rarity.UNCOMMON: (1, 3),
        Rarity.RARE: (3, 10),
        Rarity.EPIC: (10, 30),
        Rarity.LEGENDARY: (30, 100),
        Rarity.MYTHIC: (100, 500),
    }
    lo, hi = value_by_rarity[rarity]
    value = rng.randint(lo, hi) if hi > 0 else 0
    kind = rng.choices(
        ["coins", "gift_card", "cosmetic", "real_world", "charity_mythic"],
        weights=[5, 2, 4, 1, 1 if rarity == Rarity.MYTHIC else 0],
        k=1,
    )[0]
    label = f"{rarity.value.title()} {kind.replace('_', ' ').title()}"
    return {
        "prize": {
            "kind": kind,
            "label": label,
            "value_usd": value,
            "meta": {"theme": theme} if theme else {},
        }
    }


def generate_layers(
    *,
    rarity: Rarity,
    theme: str | None,
    seed: int,
    layer_count: int | None = None,
) -> list[GeneratedLayer]:
    """Deterministic layer generation. Same (rarity, theme, seed) = same layers."""
    rng = random.Random(seed)
    if layer_count is None:
        lo, hi = LAYER_COUNT_BY_RARITY[rarity]
        layer_count = rng.randint(lo, hi)

    mix = LAYER_MIX[rarity]
    layers: list[GeneratedLayer] = []
    for i in range(layer_count - 1):
        lt = _pick_weighted(mix, rng)
        if lt == LayerType.HINT:
            payload: dict[str, Any] = _hint_payload(rng, theme)
        elif lt == LayerType.MINI_REWARD:
            payload = _mini_reward_payload(rng, rarity)
        elif lt == LayerType.POWERUP:
            payload = _powerup_payload(rng)
        elif lt == LayerType.TRAP:
            payload = _trap_payload(rng)
        else:
            payload = {}
        layers.append(GeneratedLayer(index=i, layer_type=lt, payload=payload))

    layers.append(
        GeneratedLayer(
            index=layer_count - 1,
            layer_type=LayerType.FINAL,
            payload=_final_payload(rng, rarity, theme),
        )
    )
    return layers
