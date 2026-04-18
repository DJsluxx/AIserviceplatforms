"""Live-globe WebSocket — broadcasts package-hop events to viewers.

Auth: first message must be {"type":"auth","session_token":"..."}.
Broadcasts: {"type":"hop","payload":{id,rarity,from_lat,from_lng,to_lat,to_lng}}

Backing channel: Redis pub/sub topic `map:hops`.
"""
from __future__ import annotations

import asyncio
import contextlib
import json
from dataclasses import dataclass

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.core.auth import verify_session_token
from app.core.logging import get_logger
from app.core.redis_client import get_redis

router = APIRouter()
log = get_logger("peeled.ws.map")


@dataclass(slots=True)
class Client:
    ws: WebSocket
    user_id: str | None = None


@router.websocket("/map")
async def map_socket(ws: WebSocket) -> None:
    await ws.accept()
    client = Client(ws=ws)

    try:
        first = await asyncio.wait_for(ws.receive_json(), timeout=10.0)
    except (asyncio.TimeoutError, Exception):
        await ws.close(code=4001)
        return

    if first.get("type") != "auth" or "session_token" not in first:
        await ws.close(code=4002)
        return

    try:
        user = verify_session_token(first["session_token"])
        client.user_id = user.user_id
    except Exception:
        await ws.close(code=4003)
        return

    redis = get_redis()
    pubsub = redis.pubsub()
    await pubsub.subscribe("map:hops")

    async def pump() -> None:
        async for msg in pubsub.listen():
            if msg is None or msg.get("type") != "message":
                continue
            try:
                await ws.send_text(msg["data"])
            except Exception:
                break

    pump_task = asyncio.create_task(pump())
    try:
        while True:
            # keepalive echo
            raw = await ws.receive_text()
            with contextlib.suppress(Exception):
                if raw == "ping":
                    await ws.send_text("pong")
    except WebSocketDisconnect:
        pass
    finally:
        pump_task.cancel()
        with contextlib.suppress(Exception):
            await pubsub.unsubscribe("map:hops")
            await pubsub.close()


async def broadcast_hop(
    package_id: str,
    rarity: str,
    from_lat: float,
    from_lng: float,
    to_lat: float,
    to_lng: float,
) -> None:
    redis = get_redis()
    payload = json.dumps(
        {
            "type": "hop",
            "payload": {
                "id": package_id,
                "rarity": rarity,
                "from_lat": from_lat,
                "from_lng": from_lng,
                "to_lat": to_lat,
                "to_lng": to_lng,
            },
        }
    )
    await redis.publish("map:hops", payload)
