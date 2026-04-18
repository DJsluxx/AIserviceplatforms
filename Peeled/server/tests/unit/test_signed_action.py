"""Signed-action token tests."""
from __future__ import annotations

import pytest

from app.core.errors import ApiError
from app.core.signed_action import parse, sign


def test_sign_and_parse_roundtrip() -> None:
    token = sign("peel", "user1", "pkg1")
    payload = parse(token)
    assert payload.action == "peel"
    assert payload.user_id == "user1"
    assert payload.package_id == "pkg1"
    assert payload.exp > payload.iat


def test_parse_rejects_tampered_token() -> None:
    token = sign("peel", "user1", "pkg1")
    body, sig = token.split(".")
    # flip the last char of the body to invalidate
    tampered = body[:-1] + ("A" if body[-1] != "A" else "B") + "." + sig
    with pytest.raises(ApiError) as exc:
        parse(tampered)
    assert exc.value.code == "ACTION_SIGNATURE_INVALID"


def test_parse_rejects_malformed() -> None:
    with pytest.raises(ApiError):
        parse("no-dot-here")


@pytest.mark.asyncio
async def test_consume_enforces_single_use() -> None:
    from app.core.signed_action import consume

    token = sign("peel", "user1", "pkg1")
    await consume(token, "peel", "user1", "pkg1")
    with pytest.raises(ApiError) as exc:
        await consume(token, "peel", "user1", "pkg1")
    assert exc.value.code == "NONCE_REPLAYED"


@pytest.mark.asyncio
async def test_consume_rejects_wrong_user() -> None:
    from app.core.signed_action import consume

    token = sign("peel", "user1", "pkg1")
    with pytest.raises(ApiError) as exc:
        await consume(token, "peel", "other_user", "pkg1")
    assert exc.value.code == "FORBIDDEN"


@pytest.mark.asyncio
async def test_consume_rejects_wrong_action() -> None:
    from app.core.signed_action import consume

    token = sign("peel", "user1", "pkg1")
    with pytest.raises(ApiError) as exc:
        await consume(token, "pass", "user1", "pkg1")
    assert exc.value.code == "ACTION_SIGNATURE_INVALID"
