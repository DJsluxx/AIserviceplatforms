"""Auth schemas."""
from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    supabase_jwt: str = Field(..., min_length=20)
    device_id: str | None = None


class LoginResponse(BaseModel):
    session_token: str
    expires_at: datetime
    user_id: str


class ActionTokenRequest(BaseModel):
    action: str = Field(..., pattern=r"^(peel|pass|send_to_friend|create_package)$")
    package_id: str | None = None


class ActionTokenResponse(BaseModel):
    token: str
    expires_at: datetime
