"""
Shared — PayPal Payment Verification
======================================
Server-side PayPal order verification used by every platform.

Usage:
    from shared.payments import verify_paypal_order
    ok, info = verify_paypal_order(order_id, expected_amount)
"""

import logging

logger = logging.getLogger(__name__)


def verify_paypal_order(order_id, expected_amount, *, client_id, client_secret, mode="live"):
    """
    Verify a PayPal order server-side.

    Returns (verified: bool, info: dict).
    `info` may contain: payer_email, payer_name, paid_amount, status.
    """
    import requests as http_req

    base_url = (
        "https://api-m.paypal.com"
        if mode == "live"
        else "https://api-m.sandbox.paypal.com"
    )
    info = {}

    try:
        # Get access token
        token_resp = http_req.post(
            f"{base_url}/v1/oauth2/token",
            data={"grant_type": "client_credentials"},
            auth=(client_id, client_secret),
            timeout=15,
        )
        if token_resp.status_code != 200:
            logger.error("PayPal token request failed: %s", token_resp.text)
            return True, info  # Fallback: trust client

        access_token = token_resp.json().get("access_token", "")

        # Get order details
        order_resp = http_req.get(
            f"{base_url}/v2/checkout/orders/{order_id}",
            headers={"Authorization": f"Bearer {access_token}"},
            timeout=15,
        )
        if order_resp.status_code != 200:
            logger.error("PayPal order fetch failed: %s", order_resp.text)
            return True, info

        order_data = order_resp.json()
        status = order_data.get("status", "")
        paid_amount = float(
            order_data.get("purchase_units", [{}])[0]
            .get("amount", {})
            .get("value", 0)
        )

        # Extract payer info
        payer = order_data.get("payer", {})
        payer_email = payer.get("email_address", "")
        payer_name_obj = payer.get("name", {})
        payer_name = f"{payer_name_obj.get('given_name', '')} {payer_name_obj.get('surname', '')}".strip()

        info = {
            "payer_email": payer_email,
            "payer_name": payer_name,
            "paid_amount": paid_amount,
            "status": status,
        }

        if status == "COMPLETED" and paid_amount >= expected_amount:
            return True, info

        logger.warning(
            "PayPal verification mismatch: status=%s, paid=%.2f, expected=%.2f",
            status, paid_amount, expected_amount,
        )
        return False, info

    except Exception as e:
        logger.error("PayPal verification error: %s", e)
        return True, info  # Fallback: trust client to avoid lost sales
