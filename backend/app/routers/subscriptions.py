import hashlib
import hmac
import uuid
from datetime import datetime, timedelta, timezone

import structlog
from fastapi import APIRouter, Depends, HTTPException, Header, Request, status
from pydantic import ValidationError
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.dependencies import get_current_user
from app.models import Profile, Subscription
from app.rate_limit import limiter
from app.schemas import (
    CreatePaymentRequest,
    CreatePaymentResponse,
    SubscriptionOut,
    WebhookPayload,
)
from app.services.yookassa import create_payment

logger = structlog.get_logger()
router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])

PLAN_DURATION = {"monthly": timedelta(days=30), "yearly": timedelta(days=365)}


@router.post("/create-payment", response_model=CreatePaymentResponse)
@limiter.limit("5/minute")
async def create_subscription_payment(
    request: Request,
    body: CreatePaymentRequest,
    user: Profile = Depends(get_current_user),
    idempotency_key: str | None = Header(default=None, alias="Idempotence-Key"),
):
    key = (idempotency_key or "").strip() or str(uuid.uuid4())
    try:
        payment_url, payment_id = await create_payment(
            plan=body.plan,
            user_id=user.id,
            idempotency_key=key,
        )
    except RuntimeError as e:
        detail = str(e)
        low = detail.lower()
        code = (
            status.HTTP_503_SERVICE_UNAVAILABLE
            if "not configured" in low or "return url" in low
            else status.HTTP_502_BAD_GATEWAY
        )
        raise HTTPException(status_code=code, detail=detail) from e
    except Exception as e:
        logger.exception("create_payment_failed", user_id=str(user.id), plan=body.plan)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Payment provider error",
        ) from e

    return CreatePaymentResponse(payment_url=payment_url, payment_id=payment_id)


@router.get("/me", response_model=SubscriptionOut | None)
async def my_subscription(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.now(timezone.utc)
    result = await db.execute(
        select(Subscription)
        .where(Subscription.user_id == user.id, Subscription.status == "active")
        .order_by(Subscription.expires_at.desc())
        .limit(1)
    )
    sub = result.scalar_one_or_none()
    if sub is None:
        return None

    if sub.expires_at < now:
        sub.status = "expired"
        user.is_premium = False
        await db.commit()
        return None

    return SubscriptionOut.model_validate(sub)


@router.post("/webhook", status_code=200)
@limiter.limit("30/minute")
async def payment_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db),
    x_webhook_signature: str | None = Header(default=None),
):
    raw_body = await request.body()

    if settings.webhook_secret:
        expected = hmac.HMAC(
            settings.webhook_secret.encode(), raw_body, hashlib.sha256
        ).hexdigest()
        if not hmac.compare_digest(expected, x_webhook_signature or ""):
            raise HTTPException(status_code=403, detail="Invalid webhook signature")

    try:
        body = WebhookPayload.model_validate_json(raw_body)
    except ValidationError as e:
        raise HTTPException(status_code=422, detail=e.errors()) from e

    logger.info("payment_webhook", event=body.event, payment_id=body.payment_id, user_id=str(body.user_id))

    if body.event == "payment.succeeded":
        duration = PLAN_DURATION.get(body.plan, timedelta(days=30))
        now = datetime.now(timezone.utc)

        existing = await db.execute(
            select(Subscription)
            .where(Subscription.user_id == body.user_id, Subscription.status == "active")
            .order_by(Subscription.expires_at.desc())
            .limit(1)
        )
        current = existing.scalar_one_or_none()
        start = current.expires_at if current and current.expires_at > now else now

        sub = Subscription(
            user_id=body.user_id,
            plan=body.plan,
            status="active",
            started_at=start,
            expires_at=start + duration,
            payment_id=body.payment_id,
        )
        db.add(sub)

        await db.execute(
            update(Profile).where(Profile.id == body.user_id).values(is_premium=True)
        )
        await db.commit()
        logger.info("subscription_activated", user_id=str(body.user_id), plan=body.plan)

    elif body.event == "payment.cancelled":
        await db.execute(
            update(Subscription)
            .where(Subscription.payment_id == body.payment_id)
            .values(status="cancelled")
        )
        await db.commit()
        logger.info("subscription_cancelled", payment_id=body.payment_id)

    return {"status": "ok"}
