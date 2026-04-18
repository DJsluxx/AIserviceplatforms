"""Shared test fixtures."""
from __future__ import annotations

import os

os.environ.setdefault("PEELED_ENV", "test")
os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://test:test@localhost/peeled_test")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/15")
os.environ.setdefault("JWT_SECRET", "test-jwt-secret-please-change-in-prod-12345")
os.environ.setdefault("ANTI_CHEAT_SIGNING_SECRET", "test-ac-secret-change-in-prod-67890")

import pytest  # noqa: E402


@pytest.fixture(autouse=True)
def _settings_cache_clear():
    from app.core.config import get_settings

    get_settings.cache_clear()
    yield
    get_settings.cache_clear()
