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
    PRO_CREDITS = 30
    BUSINESS_CREDITS = 100

    # ── One-Time Credit Packs ──────────────────────────────
    CREDIT_PACKS = [
        {"id": "starter",  "credits": 5,   "price": 4.99,  "per_credit": 1.00, "label": "Starter"},
        {"id": "popular",  "credits": 15,  "price": 11.99, "per_credit": 0.80, "label": "Most Popular", "badge": True},
        {"id": "pro_pack", "credits": 50,  "price": 29.99, "per_credit": 0.60, "label": "Pro Pack"},
        {"id": "agency",   "credits": 150, "price": 69.99, "per_credit": 0.47, "label": "Agency", "badge_text": "Best Value"},
    ]

    # ── Subscription Plans ─────────────────────────────────
    SUBSCRIPTIONS = {
        "pro_monthly":      {"plan": "pro",      "billing": "monthly", "price": 12.99,  "credits": 30,  "label": "Pro Monthly"},
        "pro_annual":       {"plan": "pro",      "billing": "annual",  "price": 99.99,  "credits": 30,  "label": "Pro Annual",       "monthly_eq": 8.33,  "save_pct": 36},
        "business_monthly": {"plan": "business", "billing": "monthly", "price": 29.99,  "credits": 100, "label": "Business Monthly"},
        "business_annual":  {"plan": "business", "billing": "annual",  "price": 249.99, "credits": 100, "label": "Business Annual", "monthly_eq": 20.83, "save_pct": 30},
    }
