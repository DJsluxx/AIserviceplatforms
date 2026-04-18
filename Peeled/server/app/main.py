"""PEELED FastAPI application entrypoint.

Wires: Sentry, structured logging, CORS, error handlers, Prometheus, routers.
"""
from __future__ import annotations

from contextlib import asynccontextmanager
from typing import AsyncIterator

import sentry_sdk
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest
from sentry_sdk.integrations.fastapi import FastApiIntegration

from app.api.v1 import (
    auth as auth_routes,
    friends as friends_routes,
    leaderboard as leaderboard_routes,
    map_routes,
    packages as package_routes,
    reports as report_routes,
    shop as shop_routes,
    users as user_routes,
)
from app.api.ws import map_ws
from app.core.config import get_settings
from app.core.errors import ApiError, api_error_handler, generic_error_handler
from app.core.logging import configure_logging, get_logger
from app.core.redis_client import close_redis


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    configure_logging(settings.log_level)
    log = get_logger("peeled.startup")

    if settings.sentry_dsn:
        sentry_sdk.init(
            dsn=settings.sentry_dsn,
            environment=settings.env,
            traces_sample_rate=0.1 if settings.is_prod else 1.0,
            profiles_sample_rate=0.05 if settings.is_prod else 0.5,
            integrations=[FastApiIntegration()],
            send_default_pii=False,
        )
        log.info("sentry.initialized")

    log.info("peeled.api.ready", env=settings.env)
    try:
        yield
    finally:
        await close_redis()
        log.info("peeled.api.shutdown")


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title="PEELED API",
        version="0.1.0",
        docs_url="/docs" if not settings.is_prod else None,
        redoc_url=None,
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_allowed_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["*"],
        max_age=600,
    )

    app.add_exception_handler(ApiError, api_error_handler)
    app.add_exception_handler(Exception, generic_error_handler)

    @app.get("/health", tags=["meta"])
    async def health() -> dict[str, str]:
        return {"status": "ok", "env": settings.env}

    @app.get("/metrics", tags=["meta"])
    async def metrics() -> Response:
        return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

    @app.middleware("http")
    async def add_request_id(request: Request, call_next):  # type: ignore[no-untyped-def]
        rid = request.headers.get("x-request-id")
        response = await call_next(request)
        if rid:
            response.headers["x-request-id"] = rid
        return response

    prefix = "/api/v1"
    app.include_router(auth_routes.router, prefix=f"{prefix}/auth", tags=["auth"])
    app.include_router(package_routes.router, prefix=f"{prefix}/packages", tags=["packages"])
    app.include_router(user_routes.router, prefix=f"{prefix}/users", tags=["users"])
    app.include_router(friends_routes.router, prefix=f"{prefix}/friends", tags=["friends"])
    app.include_router(
        leaderboard_routes.router, prefix=f"{prefix}/leaderboard", tags=["leaderboard"]
    )
    app.include_router(shop_routes.router, prefix=f"{prefix}/shop", tags=["shop"])
    app.include_router(report_routes.router, prefix=f"{prefix}/reports", tags=["reports"])
    app.include_router(map_routes.router, prefix=f"{prefix}/map", tags=["map"])
    app.include_router(map_ws.router, prefix="/ws", tags=["ws"])

    return app


app = create_app()


if __name__ == "__main__":  # pragma: no cover
    import uvicorn

    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
