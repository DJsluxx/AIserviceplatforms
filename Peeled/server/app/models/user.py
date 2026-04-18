"""User domain model."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True, slots=True)
class User:
    id: str
    display_name: str
    handle: str
    xp: int = 0
    level: int = 1
    streak_days: int = 0
    last_active_at: datetime | None = None
    is_shadow_banned: bool = False
    country_code: str | None = None
    created_at: datetime | None = None
