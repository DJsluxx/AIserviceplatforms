"""User-facing schemas."""
from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field


class UserPublic(BaseModel):
    id: str
    display_name: str
    handle: str
    level: int
    xp: int
    streak_days: int
    country_code: str | None = None


class UpdateProfileRequest(BaseModel):
    display_name: str | None = Field(default=None, min_length=2, max_length=40)
    handle: str | None = Field(default=None, min_length=3, max_length=24, pattern=r"^[a-z0-9_]+$")
    country_code: str | None = Field(default=None, pattern=r"^[A-Z]{2}$")


class FriendRequest(BaseModel):
    target_user_id: str


class LeaderboardEntry(BaseModel):
    rank: int
    user: UserPublic
    score: int


class Leaderboard(BaseModel):
    kind: str
    entries: list[LeaderboardEntry]
    window_start: datetime
    window_end: datetime
