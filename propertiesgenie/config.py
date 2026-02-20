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
    BUSINESS_CREDITS = 90

    # ── One-Time Credit Packs ──────────────────────────────
    CREDIT_PACKS = [
        {"id": "starter",  "credits": 5,   "price": 7.50,  "per_credit": 1.50, "label": "Starter"},
        {"id": "popular",  "credits": 15,  "price": 17.50, "per_credit": 1.17, "label": "Most Popular", "badge": True},
        {"id": "pro_pack", "credits": 50,  "price": 42.50, "per_credit": 0.85, "label": "Pro Pack"},
        {"id": "agency",   "credits": 150, "price": 99.50, "per_credit": 0.66, "label": "Agency", "badge_text": "Best Value"},
    ]

    # ── Subscription Plans ─────────────────────────────────
    SUBSCRIPTIONS = {
        "pro_monthly":      {"plan": "pro",      "billing": "monthly", "price": 19.50,  "credits": 30,  "label": "Top Agent Monthly"},
        "pro_annual":       {"plan": "pro",      "billing": "annual",  "price": 149.00, "credits": 30,  "label": "Top Agent Annual",       "monthly_eq": 12.42, "save_pct": 36},
        "business_monthly": {"plan": "business", "billing": "monthly", "price": 49.50,  "credits": 90,  "label": "Elite Broker Monthly"},
        "business_annual":  {"plan": "business", "billing": "annual",  "price": 399.00, "credits": 90,  "label": "Elite Broker Annual", "monthly_eq": 33.25, "save_pct": 33},
    }

    # ── Launch Discount ────────────────────────────────────
    LAUNCH_DISCOUNT = {
        "enabled":    True,
        "percent":    30,
        "annual_extra": 10,            # extra % off for annual billing (30+10=40)
        "banner":     "We just launched!",
        "badge":      "30% OFF EVERYTHING",
        "note":       "Automatically applied at checkout \u2014 no code needed!",
    }
