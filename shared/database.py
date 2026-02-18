"""
Shared — Database
=================
Single SQLAlchemy instance shared by every platform.
Each platform defines its own models using this `db` object — just prefix
table names (pg_, xx_, etc.) so they coexist in the same Neon database.

Also provides a BaseUserMixin with the columns every platform user needs.
"""

from datetime import datetime, timezone
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()


class BaseUserMixin:
    """
    Mixin that adds common user columns.
    Usage:
        class PGUser(BaseUserMixin, UserMixin, db.Model):
            __tablename__ = "pg_users"
            # add platform-specific columns here …
    """
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=True)  # nullable for Google-only users
    name = db.Column(db.String(120), default="")
    google_id = db.Column(db.String(200), unique=True, nullable=True)
    avatar_url = db.Column(db.String(500), nullable=True)
    plan = db.Column(db.String(20), default="free")
    credits_used = db.Column(db.Integer, default=0)
    bonus_credits = db.Column(db.Integer, default=0)   # one-time purchased credits (never reset)
    billing_cycle = db.Column(db.String(10), default="monthly")  # "monthly" or "annual"
    credits_reset_at = db.Column(
        db.DateTime, default=lambda: datetime.now(timezone.utc)
    )
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(
        db.DateTime, default=lambda: datetime.now(timezone.utc)
    )


class BaseSubscriptionMixin:
    """Common subscription columns."""
    id = db.Column(db.Integer, primary_key=True)
    paypal_subscription_id = db.Column(db.String(200))
    paypal_order_id = db.Column(db.String(200))
    plan = db.Column(db.String(20), nullable=False)
    amount = db.Column(db.Float, nullable=False)
    status = db.Column(db.String(20), default="active")
    started_at = db.Column(
        db.DateTime, default=lambda: datetime.now(timezone.utc)
    )
    expires_at = db.Column(db.DateTime)
    created_at = db.Column(
        db.DateTime, default=lambda: datetime.now(timezone.utc)
    )


class BaseContactMixin:
    """Common contact-form columns."""
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(120), nullable=False)
    email = db.Column(db.String(120), nullable=False)
    subject = db.Column(db.String(200))
    message = db.Column(db.Text, nullable=False)
    is_read = db.Column(db.Boolean, default=False)
    created_at = db.Column(
        db.DateTime, default=lambda: datetime.now(timezone.utc)
    )


class BaseUsageLogMixin:
    """Common usage-log columns."""
    id = db.Column(db.Integer, primary_key=True)
    action = db.Column(db.String(50), nullable=False)
    tokens_used = db.Column(db.Integer, default=0)
    model = db.Column(db.String(50))
    created_at = db.Column(
        db.DateTime, default=lambda: datetime.now(timezone.utc)
    )


def init_db(app):
    """Initialize the shared db instance with a Flask app and create tables."""
    db.init_app(app)
    with app.app_context():
        db.create_all()
    return db
