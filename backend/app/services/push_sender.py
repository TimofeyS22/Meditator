"""
Push notification sender using FCM HTTP v1 API (legacy key fallback).

Sends push notifications to user devices via stored FCM tokens.
Requires FCM_SERVER_KEY in environment for legacy API,
or GOOGLE_APPLICATION_CREDENTIALS for HTTP v1.
"""

import httpx
import structlog
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import PushToken, ScheduledNotification

logger = structlog.get_logger()

FCM_LEGACY_URL = "https://fcm.googleapis.com/fcm/send"


async def send_push_to_user(
    user_id,
    title: str,
    body: str,
    data: dict | None = None,
    db: AsyncSession | None = None,
) -> int:
    """Send push to all devices of a user. Returns count of successful sends."""
    if not settings.fcm_server_key:
        logger.warning("fcm_server_key_not_set", user_id=str(user_id))
        return 0

    if db is None:
        from app.database import async_session
        async with async_session() as db:
            return await _send_to_tokens(user_id, title, body, data, db)
    return await _send_to_tokens(user_id, title, body, data, db)


async def _send_to_tokens(
    user_id,
    title: str,
    body: str,
    data: dict | None,
    db: AsyncSession,
) -> int:
    result = await db.execute(
        select(PushToken).where(PushToken.user_id == user_id)
    )
    tokens = result.scalars().all()
    if not tokens:
        logger.debug("no_push_tokens", user_id=str(user_id))
        return 0

    sent = 0
    stale_ids = []

    async with httpx.AsyncClient(timeout=10) as client:
        for pt in tokens:
            payload = {
                "to": pt.token,
                "notification": {"title": title, "body": body},
                "data": data or {},
                "priority": "high",
            }
            try:
                resp = await client.post(
                    FCM_LEGACY_URL,
                    json=payload,
                    headers={
                        "Authorization": f"key={settings.fcm_server_key}",
                        "Content-Type": "application/json",
                    },
                )
                result_data = resp.json()
                if result_data.get("success", 0) > 0:
                    sent += 1
                elif result_data.get("failure", 0) > 0:
                    results = result_data.get("results", [])
                    for r in results:
                        err = r.get("error", "")
                        if err in ("NotRegistered", "InvalidRegistration"):
                            stale_ids.append(pt.id)
                            logger.info("stale_push_token", token_id=str(pt.id))
            except Exception:
                logger.exception("fcm_send_error", token_id=str(pt.id))

    if stale_ids:
        await db.execute(delete(PushToken).where(PushToken.id.in_(stale_ids)))
        await db.commit()

    logger.info(
        "push_sent",
        user_id=str(user_id),
        sent=sent,
        total_tokens=len(tokens),
        stale=len(stale_ids),
    )
    return sent


async def send_pending_notifications(db: AsyncSession) -> int:
    """Process and send all pending scheduled notifications."""
    from datetime import datetime, timezone

    now = datetime.now(timezone.utc)
    result = await db.execute(
        select(ScheduledNotification)
        .where(
            ScheduledNotification.sent.is_(False),
            ScheduledNotification.scheduled_at <= now,
        )
        .limit(100)
    )
    notifications = result.scalars().all()
    total_sent = 0

    for notif in notifications:
        action_data = notif.action_data or {}
        data = {
            "action_type": notif.action_type,
            "route": action_data.get("route", ""),
        }
        count = await send_push_to_user(
            notif.user_id,
            notif.title,
            notif.body,
            data=data,
            db=db,
        )
        notif.sent = True
        total_sent += count

    if notifications:
        await db.commit()
        logger.info("pending_notifications_processed", count=len(notifications), sent=total_sent)

    return total_sent
