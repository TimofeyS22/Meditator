import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.dependencies import get_current_user
from app.models import Profile, PushToken, ScheduledNotification
from app.schemas import PushTokenRegister, PushTokenRemove, ScheduledNotificationOut

router = APIRouter(prefix="/notifications", tags=["notifications"])
logger = structlog.get_logger()


@router.post("/token", status_code=204)
async def register_push_token(
    body: PushTokenRegister,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Register or refresh an FCM/APNs device token for the authenticated user."""
    log = logger.bind(user_id=str(user.id), platform=body.platform)
    if not settings.fcm_server_key:
        log.debug("fcm_server_key_empty_server_still_stores_token")

    result = await db.execute(
        select(PushToken).where(PushToken.user_id == user.id, PushToken.token == body.token)
    )
    row = result.scalar_one_or_none()
    if row:
        row.platform = body.platform[:20]
    else:
        db.add(
            PushToken(
                user_id=user.id,
                token=body.token,
                platform=(body.platform or "ios")[:20],
            )
        )
    await db.commit()
    log.info("push_token_registered")


@router.delete("/token", status_code=204)
async def remove_push_token(
    body: PushTokenRemove,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Remove a device token for the authenticated user."""
    result = await db.execute(
        delete(PushToken).where(PushToken.user_id == user.id, PushToken.token == body.token)
    )
    if result.rowcount == 0:
        await db.rollback()
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Token not found")
    await db.commit()
    logger.info("push_token_removed", user_id=str(user.id))


@router.post("/analyze", status_code=200)
async def trigger_analysis(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Trigger proactive intelligence analysis for the authenticated user."""
    from app.services.intelligence_engine import analyze_and_schedule

    created = await analyze_and_schedule(user.id, db)
    return {"created": created}


@router.post("/send-pending", status_code=200)
async def send_pending(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Process and send all overdue scheduled notifications via FCM."""
    from app.services.push_sender import send_pending_notifications

    sent = await send_pending_notifications(db)
    return {"sent": sent}


@router.get("/pending", response_model=list[ScheduledNotificationOut])
async def list_pending_notifications(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Unsent scheduled notifications for the current user (including overdue)."""
    q = (
        select(ScheduledNotification)
        .where(
            ScheduledNotification.user_id == user.id,
            ScheduledNotification.sent.is_(False),
        )
        .order_by(ScheduledNotification.scheduled_at.asc())
    )
    result = await db.execute(q)
    rows = result.scalars().all()
    logger.debug("pending_notifications_fetched", user_id=str(user.id), count=len(rows))
    return [ScheduledNotificationOut.model_validate(r) for r in rows]
