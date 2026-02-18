"""
Properties Genie — Platform Configuration
Inherits everything from shared BaseConfig, adds platform-specific settings.
"""
import os
import sys

# ── Make shared/ importable ───────────────────────────────────
_root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
if _root not in sys.path:
    sys.path.insert(0, _root)

from shared.config_base import BaseConfig


class Config(BaseConfig):
    """Properties Genie specific config."""

    SQLALCHEMY_DATABASE_URI = BaseConfig._build_db_url()

    # Site identity
    SITE_NAME = "Properties Genie"
    SITE_URL = os.getenv("SITE_URL", "https://propertiesgenie.com")

    # Credit plans
    FREE_CREDITS = 1
    PRO_CREDITS = 100
    UNLIMITED_CREDITS = 999_999

    # Pricing (USD / month)
    PRO_PRICE = 9.99
    UNLIMITED_PRICE = 19.99
