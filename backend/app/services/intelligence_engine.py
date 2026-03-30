"""Proactive scheduling: mood + session patterns → ScheduledNotification rows.

Aura's proactive intelligence — she doesn't wait, she anticipates.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import UUID

import structlog
from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import MoodEntry, Profile, ScheduledNotification, Session as PracticeSession

logger = structlog.get_logger()

_STRESS_TOKENS = frozenset(
    {
        "stress", "stressed", "anxious", "anxiety", "overwhelmed",
        "worried", "tense", "nervous", "panic",
        "страх", "стресс", "тревог", "беспокой", "паник",
        "напряж", "устал", "истощ", "выгор",
    }
)

_WEEKDAY_NAMES_RU = {
    0: "понедельник", 1: "вторник", 2: "среда",
    3: "четверг", 4: "пятница", 5: "суббота", 6: "воскресенье",
}

_WEEKDAY_GENT_RU = {
    0: "понедельнику", 1: "вторнику", 2: "среде",
    3: "четвергу", 4: "пятнице", 5: "субботе", 6: "воскресенью",
}


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _emotion_stressful(primary: str) -> bool:
    p = primary.lower()
    return any(t in p for t in _STRESS_TOKENS)


def _profile_stress_high(profile: Profile) -> bool:
    if not profile.stress_level:
        return False
    s = profile.stress_level.lower()
    return any(x in s for x in ("high", "very", "severe", "высок"))


def _median_practice_hour(sessions: list[PracticeSession]) -> int | None:
    hours: list[int] = []
    for s in sessions:
        if s.completed and s.created_at:
            hours.append(s.created_at.hour)
    if not hours:
        return None
    hours.sort()
    return hours[len(hours) // 2]


def _stress_day_pattern(moods: list[MoodEntry]) -> int | None:
    """Find the day of week with the most stressful moods (needs >= 2 occurrences)."""
    day_stress: dict[int, int] = {}
    for m in moods:
        if _emotion_stressful(m.primary_emotion):
            wd = m.created_at.weekday()
            day_stress[wd] = day_stress.get(wd, 0) + 1
    if not day_stress:
        return None
    worst = max(day_stress, key=lambda k: day_stress[k])
    return worst if day_stress[worst] >= 2 else None


def _next_local_slot_utc(now: datetime, hour: int, minute: int) -> datetime:
    candidate = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
    if candidate <= now:
        candidate += timedelta(days=1)
    return candidate


def _next_weekday_utc(now: datetime, weekday: int, hour: int, minute: int) -> datetime:
    days_ahead = (weekday - now.weekday()) % 7
    if days_ahead == 0:
        candidate = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
        if candidate <= now:
            candidate += timedelta(days=7)
        return candidate
    return (now + timedelta(days=days_ahead)).replace(
        hour=hour, minute=minute, second=0, microsecond=0,
    )


def _next_sunday_10_utc(now: datetime) -> datetime:
    days_ahead = (6 - now.weekday()) % 7
    target = (now + timedelta(days=days_ahead)).replace(hour=10, minute=0, second=0, microsecond=0)
    if days_ahead == 0 and target <= now:
        target += timedelta(days=7)
    return target


async def _has_future_pending(
    db: AsyncSession, user_id: UUID, action_type: str, *, from_time: datetime,
) -> bool:
    q = (
        select(func.count())
        .select_from(ScheduledNotification)
        .where(
            and_(
                ScheduledNotification.user_id == user_id,
                ScheduledNotification.sent.is_(False),
                ScheduledNotification.action_type == action_type,
                ScheduledNotification.scheduled_at >= from_time,
            )
        )
    )
    n = (await db.execute(q)).scalar_one()
    return int(n or 0) > 0


async def _has_any_unsent(db: AsyncSession, user_id: UUID, action_type: str) -> bool:
    q = (
        select(func.count())
        .select_from(ScheduledNotification)
        .where(
            and_(
                ScheduledNotification.user_id == user_id,
                ScheduledNotification.sent.is_(False),
                ScheduledNotification.action_type == action_type,
            )
        )
    )
    n = (await db.execute(q)).scalar_one()
    return int(n or 0) > 0


async def analyze_and_schedule(user_id: UUID, db: AsyncSession) -> list[str]:
    """Analyze user patterns and create scheduled notifications. Returns created types."""
    log = logger.bind(user_id=str(user_id))
    log.info("intelligence_analyze_start")
    now = _utcnow()
    week_ago = now - timedelta(days=7)
    month_ago = now - timedelta(days=30)
    start_today = now.replace(hour=0, minute=0, second=0, microsecond=0)

    profile = (
        await db.execute(select(Profile).where(Profile.id == user_id))
    ).scalar_one_or_none()
    if profile is None:
        log.warning("intelligence_user_missing")
        return []

    moods = (
        (await db.execute(
            select(MoodEntry)
            .where(MoodEntry.user_id == user_id, MoodEntry.created_at >= week_ago)
            .order_by(MoodEntry.created_at.desc())
        )).scalars().all()
    )

    sessions = (
        (await db.execute(
            select(PracticeSession)
            .where(PracticeSession.user_id == user_id, PracticeSession.created_at >= month_ago)
            .order_by(PracticeSession.created_at.desc())
        )).scalars().all()
    )

    stressful_moods = [m for m in moods if _emotion_stressful(m.primary_emotion)]
    high_intensity_stress = [m for m in stressful_moods if m.intensity >= 4]
    stress_signal = (
        len(stressful_moods) >= 2
        or len(high_intensity_stress) >= 1
        or _profile_stress_high(profile)
    )

    last_completed = None
    for s in sessions:
        if s.completed:
            last_completed = s.created_at
            break

    practiced_today = bool(last_completed and last_completed >= start_today)

    typical_hour = _median_practice_hour(sessions)
    if typical_hour is None and profile.preferred_time_hour is not None:
        typical_hour = profile.preferred_time_hour

    current_hour = now.hour
    created: list[str] = []

    # 1) High stress → breathing reset
    if stress_signal and not await _has_future_pending(db, user_id, "breathing_reset", from_time=now):
        at = now + timedelta(hours=1)
        db.add(ScheduledNotification(
            user_id=user_id,
            title="Мини-перезагрузка",
            body="Последние дни были напряжёнными. 30 секунд дыхания — и станет легче.",
            action_type="breathing_reset",
            action_data={"route": "/breathe?id=box"},
            scheduled_at=at,
        ))
        created.append("breathing_reset")

    # 2) Morning check-in before usual practice time
    if typical_hour is not None and not await _has_future_pending(
        db, user_id, "morning_check_in", from_time=now,
    ):
        check_hour = (typical_hour - 1) % 24
        at = _next_local_slot_utc(now, check_hour, 55)
        db.add(ScheduledNotification(
            user_id=user_id,
            title="Утренний чек-ин",
            body="Скоро твоё привычное время практики. Как настроение сегодня?",
            action_type="morning_check_in",
            action_data={"route": "/journal/new"},
            scheduled_at=at,
        ))
        created.append("morning_check_in")

    # 3) Day-of-week stress pattern
    stress_day = _stress_day_pattern(moods)
    if stress_day is not None and not await _has_future_pending(
        db, user_id, "stress_day_prep", from_time=now,
    ):
        day_name = _WEEKDAY_NAMES_RU.get(stress_day, "этот день")
        day_gent = _WEEKDAY_GENT_RU.get(stress_day, "этому дню")
        at = _next_weekday_utc(now, stress_day, 8, 0)
        db.add(ScheduledNotification(
            user_id=user_id,
            title=f"Подготовка к {day_gent}",
            body=f"По моим наблюдениям, {day_name} для тебя бывает стрессовым. Подготовила 3-минутное дыхание.",
            action_type="stress_day_prep",
            action_data={"route": "/breathe?id=box"},
            scheduled_at=at,
        ))
        created.append("stress_day_prep")

    # 4) Gentle return after 2+ days without practice (NOT guilt, just care)
    gap = (now - last_completed) if last_completed else timedelta(days=999)
    if (
        last_completed is not None
        and gap >= timedelta(days=2)
        and not await _has_future_pending(db, user_id, "gentle_return", from_time=now)
    ):
        at = now + timedelta(hours=2)
        db.add(ScheduledNotification(
            user_id=user_id,
            title="Привет",
            body="Я здесь, когда будешь готов. Хочешь узнать, что я заметила за эту неделю?",
            action_type="gentle_return",
            action_data={"route": "/insights"},
            scheduled_at=at,
        ))
        created.append("gentle_return")

    # 5) Late night nudge
    if (23 <= current_hour or current_hour < 2) and not await _has_future_pending(
        db, user_id, "late_night", from_time=now,
    ):
        at = now + timedelta(minutes=5)
        db.add(ScheduledNotification(
            user_id=user_id,
            title="Пора отдыхать",
            body="Заметила, что ты ещё не спишь. Хочешь я подготовлю медитацию для засыпания?",
            action_type="late_night",
            action_data={"route": "/ai-play?duration=10&mood=sleep"},
            scheduled_at=at,
        ))
        created.append("late_night")

    # 6) Streak encouragement (5+ days)
    if profile.current_streak >= 5 and not await _has_future_pending(
        db, user_id, "streak_encourage", from_time=now,
    ):
        enc_hour = typical_hour or 9
        at = _next_local_slot_utc(now, (enc_hour - 1) % 24, 50)
        db.add(ScheduledNotification(
            user_id=user_id,
            title="Ты создаёшь что-то настоящее",
            body=f"{profile.current_streak} дней подряд — такая стабильность встречается редко.",
            action_type="streak_encourage",
            action_data={"route": "/home"},
            scheduled_at=at,
        ))
        created.append("streak_encourage")

    # 7) Streak at risk — active streak, no practice today, evening
    if (
        profile.current_streak > 0
        and not practiced_today
        and current_hour >= 17
        and not await _has_future_pending(db, user_id, "streak_reminder", from_time=now)
    ):
        at = now + timedelta(minutes=30)
        db.add(ScheduledNotification(
            user_id=user_id,
            title="Серия продолжается",
            body=f"У тебя {profile.current_streak} дней подряд. Даже минута дыхания сохранит серию.",
            action_type="streak_reminder",
            action_data={"route": "/breathing"},
            scheduled_at=at,
        ))
        created.append("streak_reminder")

    # 8) Weekly reflection on Sundays
    if not await _has_any_unsent(db, user_id, "weekly_reflection"):
        at = _next_sunday_10_utc(now)
        db.add(ScheduledNotification(
            user_id=user_id,
            title="Недельная рефлексия",
            body="Как прошла неделя? Запиши пару слов, пока начинается новая.",
            action_type="weekly_reflection",
            action_data={"route": "/journal/new"},
            scheduled_at=at,
        ))
        created.append("weekly_reflection")

    if created:
        await db.commit()
    log.info(
        "intelligence_analyze_done",
        created_kinds=created,
        mood_count=len(moods),
        session_count=len(sessions),
    )
    return created


async def build_monthly_summary(user_id: UUID, db: AsyncSession) -> dict:
    """Collect 30 days of data for the monthly AI digest."""
    now = _utcnow()
    month_ago = now - timedelta(days=30)

    profile = (
        await db.execute(select(Profile).where(Profile.id == user_id))
    ).scalar_one_or_none()

    moods = (
        (await db.execute(
            select(MoodEntry)
            .where(MoodEntry.user_id == user_id, MoodEntry.created_at >= month_ago)
            .order_by(MoodEntry.created_at.desc())
        )).scalars().all()
    )

    sessions = (
        (await db.execute(
            select(PracticeSession)
            .where(PracticeSession.user_id == user_id, PracticeSession.created_at >= month_ago)
            .order_by(PracticeSession.created_at.desc())
        )).scalars().all()
    )

    completed_sessions = [s for s in sessions if s.completed]
    total_minutes = sum(s.duration_seconds for s in completed_sessions) // 60

    emotion_counts: dict[str, int] = {}
    for m in moods:
        e = m.primary_emotion.lower()
        emotion_counts[e] = emotion_counts.get(e, 0) + 1

    avg_intensity = 0.0
    if moods:
        avg_intensity = sum(m.intensity for m in moods) / len(moods)

    stress_count = sum(1 for m in moods if _emotion_stressful(m.primary_emotion))

    practice_days = set()
    for s in completed_sessions:
        if s.created_at:
            practice_days.add(s.created_at.date())

    return {
        "total_sessions": len(completed_sessions),
        "total_minutes": total_minutes,
        "practice_days": len(practice_days),
        "mood_entries": len(moods),
        "top_emotions": sorted(emotion_counts.items(), key=lambda x: -x[1])[:5],
        "avg_intensity": round(avg_intensity, 1),
        "stress_entries": stress_count,
        "current_streak": profile.current_streak if profile else 0,
        "longest_streak": profile.longest_streak if profile else 0,
        "display_name": profile.display_name if profile else None,
    }
