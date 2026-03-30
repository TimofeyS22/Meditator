"""YooKassa payment creation (https://api.yookassa.ru/v3/payments)."""

from __future__ import annotations

from typing import Literal
from uuid import UUID

import httpx
import structlog

from app.config import settings

logger = structlog.get_logger()

YOOKASSA_PAYMENTS_URL = "https://api.yookassa.ru/v3/payments"

PLAN_AMOUNT: dict[str, str] = {
    "monthly": "399.00",
    "yearly": "2990.00",
}


def _default_return_url() -> str | None:
    if not settings.allowed_origins:
        return None
    base = settings.allowed_origins[0].rstrip("/")
    return f"{base}/subscription/yookassa-return"


async def create_payment(
    *,
    plan: Literal["monthly", "yearly"],
    user_id: UUID,
    idempotency_key: str,
    return_url: str | None = None,
) -> tuple[str, str]:
    """
    Create a redirect payment in YooKassa.

    Returns (confirmation_url, payment_id).

    ``idempotency_key`` is sent as the Idempotence-Key header (required by YooKassa).
    """
    shop_id = settings.yookassa_shop_id.strip()
    secret_key = settings.yookassa_secret_key.strip()
    if not shop_id or not secret_key:
        logger.warning("yookassa_not_configured")
        raise RuntimeError("YooKassa is not configured")

    effective_return = (return_url or _default_return_url() or "").strip()
    if not effective_return:
        logger.warning("yookassa_return_url_missing")
        raise RuntimeError("Payment return URL is not configured")

    amount_value = PLAN_AMOUNT[plan]
    payload = {
        "amount": {"value": amount_value, "currency": "RUB"},
        "capture": True,
        "confirmation": {
            "type": "redirect",
            "return_url": effective_return,
        },
        "description": f"Meditator premium — {plan}",
        "metadata": {
            "user_id": str(user_id),
            "plan": plan,
        },
    }

    headers = {
        "Idempotence-Key": idempotency_key,
        "Content-Type": "application/json",
    }

    async with httpx.AsyncClient(
        timeout=30.0,
        auth=httpx.BasicAuth(shop_id, secret_key),
    ) as client:
        response = await client.post(YOOKASSA_PAYMENTS_URL, json=payload, headers=headers)

    if response.is_error:
        body_preview = response.text[:500] if response.text else ""
        logger.error(
            "yookassa_create_payment_failed",
            status_code=response.status_code,
            body_preview=body_preview,
            plan=plan,
            user_id=str(user_id),
        )
        response.raise_for_status()

    data = response.json()
    payment_id = data.get("id")
    confirmation = data.get("confirmation") or {}
    confirmation_url = confirmation.get("confirmation_url")

    if not payment_id or not confirmation_url:
        logger.error(
            "yookassa_unexpected_response",
            has_id=bool(payment_id),
            has_confirmation_url=bool(confirmation_url),
            user_id=str(user_id),
        )
        raise RuntimeError("Unexpected YooKassa response")

    logger.info(
        "yookassa_payment_created",
        payment_id=payment_id,
        plan=plan,
        user_id=str(user_id),
    )
    return confirmation_url, payment_id
