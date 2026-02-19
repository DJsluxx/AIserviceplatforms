"""
Shared — PayPal Payment Verification & Server-Side Order Management
======================================================================
Server-side PayPal order creation, capture, and verification used by every platform.

Usage:
    from shared.payments import verify_paypal_order, create_paypal_order, capture_paypal_order
    ok, info = verify_paypal_order(order_id, expected_amount)
"""

import logging

logger = logging.getLogger(__name__)


def _get_paypal_access_token(*, client_id, client_secret, mode="live"):
    """Get a PayPal OAuth access token. Returns token string or None."""
    import requests as http_req

    base_url = (
        "https://api-m.paypal.com" if mode == "live"
        else "https://api-m.sandbox.paypal.com"
    )
    resp = http_req.post(
        f"{base_url}/v1/oauth2/token",
        data={"grant_type": "client_credentials"},
        auth=(client_id, client_secret),
        timeout=15,
    )
    if resp.status_code != 200:
        logger.error("PayPal token request failed: %s", resp.text)
        return None, base_url
    return resp.json().get("access_token", ""), base_url


def create_paypal_order(amount, currency, description, *, client_id, client_secret, mode="live"):
    """
    Create a PayPal order SERVER-SIDE so the price cannot be tampered with.
    Returns (order_id: str | None, error: str | None).
    """
    import requests as http_req

    access_token, base_url = _get_paypal_access_token(
        client_id=client_id, client_secret=client_secret, mode=mode,
    )
    if not access_token:
        return None, "Failed to authenticate with PayPal"

    try:
        resp = http_req.post(
            f"{base_url}/v2/checkout/orders",
            headers={
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json",
            },
            json={
                "intent": "CAPTURE",
                "purchase_units": [{
                    "amount": {
                        "currency_code": currency,
                        "value": f"{amount:.2f}",
                    },
                    "description": description,
                }],
            },
            timeout=15,
        )
        if resp.status_code in (200, 201):
            return resp.json().get("id"), None
        logger.error("PayPal create order failed: %s", resp.text)
        return None, "Failed to create PayPal order"
    except Exception as e:
        logger.error("PayPal create order error: %s", e)
        return None, str(e)


def capture_paypal_order(order_id, expected_amount, *, client_id, client_secret, mode="live"):
    """
    Capture a PayPal order SERVER-SIDE and verify the amount matches.
    Returns (success: bool, info: dict).
    """
    import requests as http_req

    access_token, base_url = _get_paypal_access_token(
        client_id=client_id, client_secret=client_secret, mode=mode,
    )
    if not access_token:
        return False, {"error": "Failed to authenticate with PayPal"}

    try:
        resp = http_req.post(
            f"{base_url}/v2/checkout/orders/{order_id}/capture",
            headers={
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json",
            },
            timeout=15,
        )
        data = resp.json()
        status = data.get("status", "")

        # Extract payer info
        payer = data.get("payer", {})
        payer_email = payer.get("email_address", "")
        payer_name_obj = payer.get("name", {})
        payer_name = f"{payer_name_obj.get('given_name', '')} {payer_name_obj.get('surname', '')}".strip()

        # Get captured amount
        captures = (
            data.get("purchase_units", [{}])[0]
            .get("payments", {})
            .get("captures", [{}])
        )
        paid_amount = float(captures[0].get("amount", {}).get("value", 0)) if captures else 0

        info = {
            "payer_email": payer_email,
            "payer_name": payer_name,
            "paid_amount": paid_amount,
            "status": status,
        }

        if status == "COMPLETED" and paid_amount >= expected_amount:
            return True, info

        logger.warning(
            "PayPal capture mismatch: status=%s, paid=%.2f, expected=%.2f",
            status, paid_amount, expected_amount,
        )
        return False, info

    except Exception as e:
        logger.error("PayPal capture error: %s", e)
        return False, {"error": str(e)}


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
            return False, info  # SECURE: reject on API failure

        access_token = token_resp.json().get("access_token", "")

        # Get order details
        order_resp = http_req.get(
            f"{base_url}/v2/checkout/orders/{order_id}",
            headers={"Authorization": f"Bearer {access_token}"},
            timeout=15,
        )
        if order_resp.status_code != 200:
            logger.error("PayPal order fetch failed: %s", order_resp.text)
            return False, info

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
        return False, info  # SECURE: reject on error — never trust client-side
