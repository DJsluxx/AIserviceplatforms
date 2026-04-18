"""Typed API errors with consistent envelope."""
from __future__ import annotations

from typing import Any

from fastapi import Request
from fastapi.responses import JSONResponse


class ApiError(Exception):
    def __init__(
        self,
        code: str,
        message: str,
        status_code: int = 400,
        extra: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code
        self.extra = extra or {}

    def to_body(self, request_id: str | None = None) -> dict[str, Any]:
        return {
            "ok": False,
            "error": {"code": self.code, "message": self.message, **self.extra},
            "meta": {"request_id": request_id},
        }


async def api_error_handler(request: Request, exc: ApiError) -> JSONResponse:
    rid = request.headers.get("x-request-id")
    return JSONResponse(status_code=exc.status_code, content=exc.to_body(rid))


async def generic_error_handler(request: Request, exc: Exception) -> JSONResponse:
    rid = request.headers.get("x-request-id")
    return JSONResponse(
        status_code=500,
        content={
            "ok": False,
            "error": {"code": "SERVER_ERROR", "message": "internal error"},
            "meta": {"request_id": rid},
        },
    )
