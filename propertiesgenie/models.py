"""
Properties Genie — Database Models
All table names prefixed with pg_ to share the Neon database with other platforms.
Inherits common column mixins from shared.database.
"""

import json
from datetime import datetime, timezone

from flask_login import UserMixin
from shared.database import (
    db,
    BaseUserMixin,
    BaseSubscriptionMixin,
    BaseContactMixin,
    BaseUsageLogMixin,
)
from config import Config


# ── Users ───────────────────────────────────────────────────────

class PGUser(BaseUserMixin, UserMixin, db.Model):
    __tablename__ = "pg_users"

    listings = db.relationship(
        "PGListing", backref="user", lazy=True,
        order_by="PGListing.created_at.desc()",
    )
    subscription = db.relationship(
        "PGSubscription", backref="user", uselist=False, lazy=True,
    )

    def __repr__(self):
        return f"<PGUser {self.email}>"

    @property
    def credits_remaining(self):
        limits = {
            "free": Config.FREE_CREDITS,
            "pro": Config.PRO_CREDITS,
            "business": Config.BUSINESS_CREDITS,
        }
        plan_limit = limits.get(self.plan, Config.FREE_CREDITS)
        # Free-plan users must verify email to unlock their free credit
        if self.plan == "free" and not self.email_verified:
            plan_limit = 0
        plan_credits = max(0, plan_limit - self.credits_used)
        return plan_credits + (self.bonus_credits or 0)

    @property
    def credit_limit(self):
        limits = {
            "free": Config.FREE_CREDITS,
            "pro": Config.PRO_CREDITS,
            "business": Config.BUSINESS_CREDITS,
        }
        return limits.get(self.plan, Config.FREE_CREDITS)


# ── Subscriptions ───────────────────────────────────────────────

class PGSubscription(BaseSubscriptionMixin, db.Model):
    __tablename__ = "pg_subscriptions"
    user_id = db.Column(db.Integer, db.ForeignKey("pg_users.id"), nullable=False)


# ── One-Time Credit Purchases ──────────────────────────────────

class PGCreditPurchase(db.Model):
    __tablename__ = "pg_credit_purchases"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("pg_users.id"), nullable=False)
    paypal_order_id = db.Column(db.String(200))
    pack_id = db.Column(db.String(50), nullable=False)
    credits = db.Column(db.Integer, nullable=False)
    amount = db.Column(db.Float, nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))


# ── Generated Listings ──────────────────────────────────────────

class PGListing(db.Model):
    __tablename__ = "pg_listings"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("pg_users.id"), nullable=False)

    # Property details (input)
    property_type = db.Column(db.String(50))
    listing_type = db.Column(db.String(20))
    bedrooms = db.Column(db.Integer)
    bathrooms = db.Column(db.Float)
    sqft = db.Column(db.Integer)
    lot_size = db.Column(db.String(50))
    year_built = db.Column(db.Integer)
    price = db.Column(db.String(50))
    address = db.Column(db.String(300))
    city = db.Column(db.String(100))
    state = db.Column(db.String(100))
    zip_code = db.Column(db.String(20))
    features = db.Column(db.Text)
    neighborhood_info = db.Column(db.Text)
    tone = db.Column(db.String(30))
    additional_notes = db.Column(db.Text)

    # Output
    generated_title = db.Column(db.String(300))
    generated_description = db.Column(db.Text)
    generated_highlights = db.Column(db.Text)   # JSON array
    generated_social_kit = db.Column(db.Text)   # JSON: {instagram, facebook, twitter}
    tokens_used = db.Column(db.Integer, default=0)

    # Meta
    is_favorite = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    def __repr__(self):
        return f"<PGListing {self.address or self.id}>"


# ── Usage Logs ──────────────────────────────────────────────────

class PGUsageLog(BaseUsageLogMixin, db.Model):
    __tablename__ = "pg_usage_logs"
    user_id = db.Column(db.Integer, db.ForeignKey("pg_users.id"), nullable=False)


# ── Contact Messages ────────────────────────────────────────────

class PGContact(BaseContactMixin, db.Model):
    __tablename__ = "pg_contacts"
