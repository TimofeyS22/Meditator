"""Admin analytics endpoint -- protected by admin_secret header for simplicity."""

from datetime import datetime, timedelta, timezone

import structlog
from fastapi import APIRouter, Depends, HTTPException, Header, Request
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models import MoodEntry, PairMessage, Profile, Session, Subscription

logger = structlog.get_logger()
router = APIRouter(prefix="/admin", tags=["admin"])


def _verify_admin(x_admin_secret: str = Header()):
    if not settings.admin_secret or x_admin_secret != settings.admin_secret:
        raise HTTPException(status_code=403, detail="Forbidden")


@router.get("/stats", dependencies=[Depends(_verify_admin)])
async def stats(db: AsyncSession = Depends(get_db)):
    now = datetime.now(timezone.utc)
    d7 = now - timedelta(days=7)
    d30 = now - timedelta(days=30)

    total_users = (await db.execute(select(func.count(Profile.id)))).scalar() or 0
    users_7d = (await db.execute(
        select(func.count(Profile.id)).where(Profile.created_at >= d7)
    )).scalar() or 0
    users_30d = (await db.execute(
        select(func.count(Profile.id)).where(Profile.created_at >= d30)
    )).scalar() or 0

    total_sessions = (await db.execute(select(func.count(Session.id)))).scalar() or 0
    sessions_7d = (await db.execute(
        select(func.count(Session.id)).where(Session.created_at >= d7)
    )).scalar() or 0

    total_mood = (await db.execute(select(func.count(MoodEntry.id)))).scalar() or 0
    mood_7d = (await db.execute(
        select(func.count(MoodEntry.id)).where(MoodEntry.created_at >= d7)
    )).scalar() or 0

    active_subs = (await db.execute(
        select(func.count(Subscription.id)).where(Subscription.status == "active")
    )).scalar() or 0

    total_messages = (await db.execute(select(func.count(PairMessage.id)))).scalar() or 0

    return {
        "users": {"total": total_users, "last_7d": users_7d, "last_30d": users_30d},
        "sessions": {"total": total_sessions, "last_7d": sessions_7d},
        "mood_entries": {"total": total_mood, "last_7d": mood_7d},
        "subscriptions": {"active": active_subs},
        "pair_messages": {"total": total_messages},
        "generated_at": now.isoformat(),
    }
