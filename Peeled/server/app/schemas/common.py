"""Shared response envelopes."""
from __future__ import annotations

from typing import Any, Generic, TypeVar

from pydantic import BaseModel, Field

T = TypeVar("T")


class ApiMeta(BaseModel):
    request_id: str | None = None


class ApiOk(BaseModel, Generic[T]):
    ok: bool = True
    data: T
    meta: ApiMeta = Field(default_factory=ApiMeta)


class ApiErrorBody(BaseModel):
    code: str
    message: str
    extra: dict[str, Any] = Field(default_factory=dict)
