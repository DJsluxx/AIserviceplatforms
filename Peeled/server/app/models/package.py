"""Package domain models."""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

from app.models.enums import EventType, LayerType, PackageStatus, Rarity


@dataclass(frozen=True, slots=True)
class Package:
    id: str
    creator_id: str | None
    current_holder_id: str | None
    rarity: Rarity
    total_layers: int
    peeled_layers: int
    status: PackageStatus
    hops: int
    hold_deadline: datetime | None
    created_at: datetime
    updated_at: datetime
    origin_lat: float | None = None
    origin_lng: float | None = None
    current_lat: float | None = None
    current_lng: float | None = None
    theme: str | None = None
    prize_meta: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class Layer:
    id: str
    package_id: str
    index: int
    layer_type: LayerType
    payload: dict[str, Any]


@dataclass(frozen=True, slots=True)
class Peel:
    id: str
    package_id: str
    user_id: str
    layer_index: int
    action_nonce: str
    client_ts: datetime | None
    server_ts: datetime


@dataclass(frozen=True, slots=True)
class PackageEvent:
    id: str
    package_id: str
    event_type: EventType
    actor_id: str | None
    created_at: datetime
    payload: dict[str, Any] = field(default_factory=dict)
