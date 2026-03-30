from datetime import datetime, timezone

import structlog
from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import Profile, Session
from app.schemas import SessionCreate, SessionOut

logger = structlog.get_logger()
router = APIRouter(prefix="/sessions", tags=["sessions"])


async def _update_streak(db: AsyncSession, user_id, session_row: Session):
    if not session_row.completed:
        return

    profile_result = await db.execute(select(Profile).where(Profile.id == user_id))
    profile = profile_result.scalar_one_or_none()
    if not profile:
        return

    add_minutes = max(0, session_row.duration_seconds // 60)
    profile.total_sessions += 1
    profile.total_minutes += add_minutes

    session_day = session_row.created_at.date() if session_row.created_at else datetime.now(timezone.utc).date()

    today_count = await db.scalar(
        select(func.count()).select_from(Session).where(
            Session.user_id == user_id,
            Session.completed.is_(True),
            Session.id != session_row.id,
            func.date(Session.created_at) == session_day,
        )
    )

    if today_count == 0:
        prev_date = await db.scalar(
            select(func.max(func.date(Session.created_at))).where(
                Session.user_id == user_id,
                Session.completed.is_(True),
                func.date(Session.created_at) < session_day,
            )
        )

        if prev_date is None:
            profile.current_streak = 1
        elif (session_day - prev_date).days == 1:
            profile.current_streak += 1
        else:
            profile.current_streak = 1

        if profile.current_streak > profile.longest_streak:
            profile.longest_streak = profile.current_streak

    await db.commit()
    logger.info("streak_updated", user_id=str(user_id), streak=profile.current_streak, total_sessions=profile.total_sessions)


@router.post("", response_model=SessionOut, status_code=201)
async def create_session(
    body: SessionCreate,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    s = Session(
        user_id=user.id,
        meditation_id=body.meditation_id,
        duration_seconds=body.duration_seconds,
        completed=body.completed,
        mood_before=body.mood_before,
        mood_after=body.mood_after,
    )
    db.add(s)
    await db.commit()
    await db.refresh(s)

    await _update_streak(db, user.id, s)

    try:
        from app.services.intelligence_engine import analyze_and_schedule
        await analyze_and_schedule(user.id, db)
    except Exception:
        logger.warning("intelligence_trigger_failed", user_id=str(user.id), exc_info=True)

    return SessionOut.model_validate(s)


@router.get("", response_model=list[SessionOut])
async def list_sessions(
    limit: int = Query(default=50, ge=1, le=200),
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    q = (
        select(Session)
        .where(Session.user_id == user.id)
        .order_by(Session.created_at.desc())
        .limit(limit)
    )
    result = await db.execute(q)
    return [SessionOut.model_validate(r) for r in result.scalars().all()]
