"""Unit tests for the layer engine."""
from __future__ import annotations

import pytest

from app.models.enums import LayerType, Rarity
from app.services.layer_engine import LAYER_COUNT_BY_RARITY, generate_layers


@pytest.mark.parametrize("rarity", list(Rarity))
def test_generate_layers_within_rarity_range(rarity: Rarity) -> None:
    lo, hi = LAYER_COUNT_BY_RARITY[rarity]
    layers = generate_layers(rarity=rarity, theme=None, seed=1234)
    assert lo <= len(layers) <= hi
    assert layers[-1].layer_type == LayerType.FINAL
    assert all(l.index == i for i, l in enumerate(layers))


def test_generate_layers_deterministic_for_same_seed() -> None:
    a = generate_layers(rarity=Rarity.EPIC, theme="music", seed=42)
    b = generate_layers(rarity=Rarity.EPIC, theme="music", seed=42)
    assert len(a) == len(b)
    for la, lb in zip(a, b, strict=True):
        assert la.layer_type == lb.layer_type
        assert la.payload == lb.payload


def test_generate_layers_exact_layer_count() -> None:
    layers = generate_layers(rarity=Rarity.RARE, theme=None, seed=1, layer_count=12)
    assert len(layers) == 12
    assert layers[-1].layer_type == LayerType.FINAL


def test_final_layer_has_prize() -> None:
    layers = generate_layers(rarity=Rarity.MYTHIC, theme="charity", seed=99)
    prize = layers[-1].payload.get("prize")
    assert prize is not None
    assert "kind" in prize
    assert "label" in prize
    assert "value_usd" in prize


def test_hint_layers_reference_theme_when_present() -> None:
    layers = generate_layers(rarity=Rarity.COMMON, theme="retro", seed=7)
    hint_layers = [l for l in layers if l.layer_type == LayerType.HINT]
    # at least one hint should embed the theme marker
    assert any("theme: retro" in (l.payload.get("text") or "") for l in hint_layers) or hint_layers == []
