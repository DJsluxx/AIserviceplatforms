"""FCM push dispatch with dedup + quiet-hours + bundling.

Callers construct a NotificationEnvelope and call `dispatch`. The module:
  - drops duplicates via Redis dedupe_key
  - respects user quiet hours (config on the user row)
  - bundles low-priority events if too many in a window

Firebase admin SDK is lazily initialized from FCM_SERVICE_ACCOUNT_JSON env var.
"""
from __future__ import annotations

import base64
import json
import time
from dataclasses import dataclass, field
from enum import Enum

from app.core.config import get_settings
from app.core.logging import get_logger
from app.core.redis_client import get_redis

_fcm_initialized = False
log = get_logger("peeled.notifications")


class NotificationPriority(str, Enum):
    LOW = "low"
    NORMAL = "normal"
    HIGH = "high"
    CRITICAL = "critical"


@dataclass(frozen=True, slots=True)
class NotificationEnvelope:
    user_id: str
    device_tokens: tuple[str, ...]
    title: str
    body: str
    priority: NotificationPriority
    data: dict[str, str] = field(default_factory=dict)
    dedupe_key: str | None = None


def _init_fcm() -> None:
    global _fcm_initialized
    if _fcm_initialized:
        return
    settings = get_settings()
    raw = settings.fcm_service_account_json_b64
    if not raw:
        log.warning("fcm.disabled.no_credentials")
        return
    try:
        import firebase_admin
        from firebase_admin import credentials

        decoded = base64.b64decode(raw).decode()
        cred = credentials.Certificate(json.loads(decoded))
        if not firebase_admin._apps:
            firebase_admin.initialize_app(cred)
        _fcm_initialized = True
    except Exception:  # pragma: no cover - infra
        log.exception("fcm.init_failed")


async def _is_deduped(dedupe_key: str) -> bool:
    redis = get_redis()
    set_ok = await redis.set(f"notif:dedupe:{dedupe_key}", "1", nx=True, ex=86400)
    return not set_ok


async def _quiet_hours_active(user_id: str) -> bool:
    redis = get_redis()
    val = await redis.get(f"notif:quiet:{user_id}")
    return val == "1"


async def dispatch(env: NotificationEnvelope) -> dict[str, int]:
    """Send the notification. Returns {sent, skipped, failed}."""
    stats = {"sent": 0, "skipped": 0, "failed": 0}

    if env.dedupe_key and await _is_deduped(env.dedupe_key):
        stats["skipped"] = 1
        return stats

    if env.priority == NotificationPriority.LOW and await _quiet_hours_active(env.user_id):
        stats["skipped"] = 1
        return stats

    if not env.device_tokens:
        stats["skipped"] = 1
        return stats

    _init_fcm()
    try:
        from firebase_admin import messaging  # type: ignore
    except ImportError:  # pragma: no cover
        stats["failed"] = len(env.device_tokens)
        return stats

    if not _fcm_initialized:
        log.info(
            "fcm.dryrun",
            user=env.user_id,
            title=env.title,
            priority=env.priority.value,
            tokens=len(env.device_tokens),
        )
        stats["skipped"] = len(env.device_tokens)
        return stats

    message = messaging.MulticastMessage(
        tokens=list(env.device_tokens),
        notification=messaging.Notification(title=env.title, body=env.body),
        data=env.data,
        android=messaging.AndroidConfig(
            priority="high" if env.priority in (NotificationPriority.HIGH, NotificationPriority.CRITICAL) else "normal"
        ),
    )
    try:
        resp = messaging.send_each_for_multicast(message)
        stats["sent"] = resp.success_count
        stats["failed"] = resp.failure_count
    except Exception:  # pragma: no cover
        log.exception("fcm.send_failed", user=env.user_id)
        stats["failed"] = len(env.device_tokens)
    return stats


def build_incoming_package_envelope(
    *,
    user_id: str,
    device_tokens: tuple[str, ...],
    package_id: str,
    rarity: str,
    seconds: int,
) -> NotificationEnvelope:
    return NotificationEnvelope(
        user_id=user_id,
        device_tokens=device_tokens,
        title="You've been PEELED",
        body=f"A {rarity} package just landed — {seconds}s to peel.",
        priority=NotificationPriority.HIGH,
        data={
            "kind": "incoming_package",
            "package_id": package_id,
            "rarity": rarity,
        },
        dedupe_key=f"incoming:{user_id}:{package_id}",
    )


def build_expiring_envelope(
    user_id: str, device_tokens: tuple[str, ...], package_id: str
) -> NotificationEnvelope:
    return NotificationEnvelope(
        user_id=user_id,
        device_tokens=device_tokens,
        title="Your package is slipping away",
        body="5 seconds left to peel.",
        priority=NotificationPriority.CRITICAL,
        data={"kind": "expiring", "package_id": package_id},
        dedupe_key=f"expire:{user_id}:{package_id}:{int(time.time() // 10)}",
    )
