"""
Shared — Base Configuration
Every platform inherits from BaseConfig and only overrides what's unique.
"""
import os
from dotenv import load_dotenv

load_dotenv()


class BaseConfig:
    """Common config loaded from environment variables."""

    # ── Flask ───────────────────────────────────────────────
    SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-change-in-production")
    FLASK_ENV = os.getenv("FLASK_ENV", "production")
    PORT = int(os.getenv("PORT", 5000))

    # ── Database (Neon Postgres — shared across all platforms) ──
    @staticmethod
    def _build_db_url():
        if os.getenv("FLASK_ENV") == "development":
            return "sqlite:///dev.db"
        url = os.getenv("DATABASE_URL", "sqlite:///dev.db")
        if url.startswith("postgres://"):
            url = url.replace("postgres://", "postgresql://", 1)
        if "channel_binding=require" in url:
            url = (
                url.replace("&channel_binding=require", "")
                .replace("?channel_binding=require&", "?")
                .replace("?channel_binding=require", "")
            )
        return url

    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {
        "pool_pre_ping": True,
        "pool_recycle": 280,
        "pool_size": 5,
        "max_overflow": 10,
    }

    # ── AI ──────────────────────────────────────────────────
    OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
    OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

    # ── PayPal ──────────────────────────────────────────────
    PAYPAL_CLIENT_ID = os.getenv("PAYPAL_CLIENT_ID", "")
    PAYPAL_CLIENT_SECRET = os.getenv("PAYPAL_CLIENT_SECRET", "")
    PAYPAL_MODE = os.getenv("PAYPAL_MODE", "live")  # live | sandbox

    # ── Email ───────────────────────────────────────────────
    MAIL_SERVER = os.getenv("MAIL_SERVER", "smtp.gmail.com")
    MAIL_PORT = int(os.getenv("MAIL_PORT", 587))
    MAIL_USE_TLS = os.getenv("MAIL_USE_TLS", "true").lower() == "true"
    MAIL_USERNAME = os.getenv("MAIL_USERNAME", "")
    MAIL_PASSWORD = os.getenv("MAIL_PASSWORD", "")
    MAIL_DEFAULT_SENDER = os.getenv("MAIL_DEFAULT_SENDER", "")
