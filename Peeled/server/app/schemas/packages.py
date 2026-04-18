"""Package API schemas."""
from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field

from app.models.enums import LayerType, PackageStatus, Rarity


class PackageOut(BaseModel):
    id: str
    rarity: Rarity
    status: PackageStatus
    total_layers: int
    peeled_layers: int
    hops: int
    hold_deadline: datetime | None
    current_holder_id: str | None
    origin_lat: float | None = None
    origin_lng: float | None = None
    current_lat: float | None = None
    current_lng: float | None = None
    theme: str | None = None
    updated_at: datetime


class PeeledLayerOut(BaseModel):
    index: int
    layer_type: LayerType
    payload: dict[str, Any]


class PeelRequest(BaseModel):
    action_token: str = Field(..., min_length=20)
    client_ts: datetime | None = None
    device_id: str | None = None


class PeelResponse(BaseModel):
    package: PackageOut
    revealed: PeeledLayerOut
    is_final: bool
    reward: dict[str, Any] | None = None


class PassRequest(BaseModel):
    action_token: str
    target_user_id: str | None = None


class SendToFriendRequest(BaseModel):
    action_token: str
    friend_user_id: str


class CreatePackageRequest(BaseModel):
    action_token: str
    theme: str | None = None
    layer_count: int | None = Field(default=None, ge=3, le=50)
    message: str | None = Field(default=None, max_length=280)


class InboxItem(BaseModel):
    package: PackageOut
    seconds_remaining: int


class Inbox(BaseModel):
    items: list[InboxItem]
    concurrent_slots_used: int
    max_concurrent_slots: int


class LiveMapPackage(BaseModel):
    id: str
    rarity: Rarity
    from_lat: float
    from_lng: float
    to_lat: float
    to_lng: float
    t_seconds: int
