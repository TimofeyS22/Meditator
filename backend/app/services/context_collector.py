"""Collects user context to personalise AI-generated meditations."""

from datetime import datetime, timedelta, timezone

import structlog
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import MoodEntry, Profile, Session

logger = structlog.get_logger()

_WEEKDAY_RU = ["понедельник", "вторник", "среда", "четверг", "пятница", "суббота", "воскресенье"]


def _time_of_day() -> str:
    hour = datetime.now(timezone.utc).hour
    if 5 <= hour < 12:
        return "утро"
    if 12 <= hour < 17:
        return "день"
    if 17 <= hour < 22:
        return "вечер"
    return "ночь"


async def collect(user: Profile, db: AsyncSession) -> dict:
    """Return a rich context dict about the user for meditation personalisation."""

    now = datetime.now(timezone.utc)
    week_ago = now - timedelta(days=7)

    mood_q = (
        select(MoodEntry)
        .where(MoodEntry.user_id == user.id, MoodEntry.created_at >= week_ago)
        .order_by(MoodEntry.created_at.desc())
        .limit(10)
    )
    moods = (await db.execute(mood_q)).scalars().all()

    session_q = (
        select(Session)
        .where(Session.user_id == user.id, Session.completed.is_(True))
        .order_by(Session.created_at.desc())
        .limit(10)
    )
    sessions = (await db.execute(session_q)).scalars().all()

    total_sessions = (
        await db.execute(
            select(func.count()).select_from(Session).where(
                Session.user_id == user.id, Session.completed.is_(True)
            )
        )
    ).scalar() or 0

    mood_texts = []
    for m in moods:
        line = f"{m.primary_emotion} ({m.intensity}/5)"
        if m.secondary_emotions:
            line += f" + {', '.join(m.secondary_emotions)}"
        if m.note:
            line += f": {m.note[:120]}"
        mood_texts.append(line)

    session_texts = []
    for s in sessions:
        mins = s.duration_seconds // 60
        session_texts.append(f"{mins}мин, завершена={s.completed}, настроение_до={s.mood_before}, после={s.mood_after}")

    weekday = _WEEKDAY_RU[now.weekday()]
    tod = _time_of_day()

    ctx = {
        "time_of_day": tod,
        "weekday": weekday,
        "goals": user.goals or [],
        "stress_level": user.stress_level or "не указан",
        "preferred_duration": user.preferred_duration or "не указана",
        "preferred_voice": user.preferred_voice or "nova",
        "experience_level": "начинающий" if total_sessions < 10 else ("средний" if total_sessions < 50 else "опытный"),
        "total_sessions": total_sessions,
        "recent_moods": mood_texts[:5],
        "recent_sessions": session_texts[:5],
    }

    summary_parts = [
        f"Сейчас {tod}, {weekday}.",
        f"Уровень опыта: {ctx['experience_level']} ({total_sessions} сессий).",
    ]
    if ctx["goals"]:
        summary_parts.append(f"Цели: {', '.join(ctx['goals'])}.")
    if ctx["stress_level"] != "не указан":
        summary_parts.append(f"Уровень стресса: {ctx['stress_level']}.")
    if mood_texts:
        summary_parts.append(f"Последнее настроение: {mood_texts[0]}.")

    ctx["summary"] = " ".join(summary_parts)

    logger.info("context_collected", user_id=str(user.id), summary_len=len(ctx["summary"]))
    return ctx
