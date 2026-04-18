"""Application configuration, loaded from environment.

Fail fast at startup if required secrets are missing in production.
"""
from __future__ import annotations

from functools import lru_cache
from typing import Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="",
        case_sensitive=False,
        extra="ignore",
    )

    env: Literal["local", "test", "dev", "prod"] = Field(default="local", alias="PEELED_ENV")
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")

    database_url: str = Field(..., alias="DATABASE_URL")
    redis_url: str = Field(..., alias="REDIS_URL")

    supabase_url: str | None = Field(default=None, alias="SUPABASE_URL")
    supabase_service_key: str | None = Field(default=None, alias="SUPABASE_SERVICE_KEY")
    supabase_jwt_secret: str | None = Field(default=None, alias="SUPABASE_JWT_SECRET")

    jwt_secret: str = Field(..., alias="JWT_SECRET")
    jwt_algorithm: str = "HS256"
    session_ttl_seconds: int = 60 * 60 * 24 * 14  # 14 days

    anti_cheat_signing_secret: str = Field(..., alias="ANTI_CHEAT_SIGNING_SECRET")
    action_token_ttl_seconds: int = 60 * 15  # 15 minutes

    fcm_service_account_json_b64: str | None = Field(default=None, alias="FCM_SERVICE_ACCOUNT_JSON")
    sentry_dsn: str | None = Field(default=None, alias="SENTRY_DSN")

    mapbox_token: str | None = Field(default=None, alias="MAPBOX_TOKEN")

    # Game config
    max_concurrent_packages_per_user: int = 3
    default_peel_window_seconds: int = 38
    max_hops_before_rarity_downgrade: int = 5
    max_hops_before_void: int = 50

    rate_limit_peels_per_minute: int = 30
    rate_limit_peels_per_hour: int = 400

    # CORS
    cors_allowed_origins: list[str] = Field(
        default_factory=lambda: ["http://localhost:3000", "http://localhost:8080"]
    )

    @field_validator("env")
    @classmethod
    def _env_default(cls, v: str) -> str:
        return v.lower()

    @property
    def is_prod(self) -> bool:
        return self.env == "prod"

    @property
    def is_test(self) -> bool:
        return self.env == "test"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]
