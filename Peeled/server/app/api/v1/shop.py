"""Shop routes — IAP receipt verification stubs and cosmetics catalog."""
from __future__ import annotations

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.core.auth import AuthenticatedUser, require_user
from app.schemas.common import ApiOk

router = APIRouter()


class ShopItem(BaseModel):
    sku: str
    label: str
    kind: str
    price_usd_cents: int
    grants: dict[str, int]


CATALOG: list[ShopItem] = [
    ShopItem(sku="coins_small", label="Pocket Coins", kind="coins",
             price_usd_cents=99, grants={"coins": 120}),
    ShopItem(sku="coins_medium", label="Big Pouch", kind="coins",
             price_usd_cents=499, grants={"coins": 700}),
    ShopItem(sku="coins_large", label="Vault", kind="coins",
             price_usd_cents=1999, grants={"coins": 3500}),
    ShopItem(sku="peeled_plus_monthly", label="PEELED Plus",
             kind="subscription", price_usd_cents=499,
             grants={"plus_months": 1}),
    ShopItem(sku="tokens_5", label="Prize Tokens x5", kind="tokens",
             price_usd_cents=299, grants={"tokens": 5}),
]


@router.get("/catalog", response_model=ApiOk[list[ShopItem]])
async def catalog(
    _user: AuthenticatedUser = Depends(require_user),
) -> ApiOk[list[ShopItem]]:
    return ApiOk(data=CATALOG)


class ReceiptVerifyRequest(BaseModel):
    platform: str  # "ios" | "android"
    sku: str
    receipt: str


@router.post("/verify-receipt", response_model=ApiOk[dict])
async def verify_receipt(
    req: ReceiptVerifyRequest,
    user: AuthenticatedUser = Depends(require_user),
) -> ApiOk[dict]:
    # Real receipt validation happens via StoreKit 2 / Play Billing webhooks.
    # This endpoint accepts client-side notifications for UI reconciliation.
    return ApiOk(data={"status": "queued", "sku": req.sku, "platform": req.platform, "user_id": user.user_id})
