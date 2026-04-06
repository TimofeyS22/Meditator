from __future__ import annotations

import json
from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy import select, func, desc
from sqlalchemy.ext.asyncio import AsyncSession
import httpx

from app.database import get_db
from app.models import User, Session, MoodEntry, Meditation
from app.auth import (
    hash_password, verify_password,
    create_access_token, create_refresh_token, decode_token,
    get_current_user,
)
from app.schemas import (
    RegisterRequest, LoginRequest, TokenResponse, RefreshRequest,
    ProfileResponse, ProfileUpdateRequest,
    MoodCreateRequest, MoodResponse, MoodHistoryResponse,
    SessionCreateRequest, SessionResponse, StatsResponse,
    CompanionRequest, CompanionResponse,
    ImmediateActionResponse, UniverseResponse,
    GenerateMeditationRequest, GenerateMeditationResponse,
    TTSRequest,
)
from app.companion import CompanionEngine
from app.config import settings

auth_router = APIRouter()
profile_router = APIRouter()
sessions_router = APIRouter()
mood_router = APIRouter()
companion_router = APIRouter()
meditations_router = APIRouter()
tts_router = APIRouter()


# ── Auth ────────────────────────────────────────────────────────────────────

@auth_router.post("/register", response_model=TokenResponse)
async def register(body: RegisterRequest, db: AsyncSession = Depends(get_db)):
    existing = await db.execute(select(User).where(User.email == body.email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Email already registered")

    user = User(
        email=body.email,
        password_hash=hash_password(body.password),
        display_name=body.display_name or body.email.split("@")[0],
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@auth_router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == body.email))
    user = result.scalar_one_or_none()
    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@auth_router.post("/refresh", response_model=TokenResponse)
async def refresh(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    user_id = decode_token(body.refresh_token, "refresh")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    result = await db.execute(select(User).where(User.id == user_id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=401, detail="User not found")

    return TokenResponse(
        access_token=create_access_token(user_id),
        refresh_token=create_refresh_token(user_id),
    )


# ── Profile ─────────────────────────────────────────────────────────────────

def _profile_response(user: User) -> ProfileResponse:
    return ProfileResponse(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        is_premium=user.is_premium,
        total_sessions=user.total_sessions,
        current_streak=user.current_streak,
        longest_streak=user.longest_streak,
        total_minutes=user.total_minutes,
        preferred_duration=user.preferred_duration,
        notification_enabled=user.notification_enabled,
        notification_hour=user.notification_hour,
        companion_tone=user.companion_tone,
        emotional_trend=user.emotional_trend,
        created_at=user.created_at,
    )


@profile_router.get("", response_model=ProfileResponse)
async def get_profile(user: User = Depends(get_current_user)):
    return _profile_response(user)


@profile_router.put("", response_model=ProfileResponse)
async def update_profile(
    body: ProfileUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    for field in ("display_name", "preferred_duration", "notification_enabled", "notification_hour"):
        val = getattr(body, field, None)
        if val is not None:
            setattr(user, field, val)
    await db.commit()
    await db.refresh(user)
    return _profile_response(user)


# ── Sessions ────────────────────────────────────────────────────────────────

@sessions_router.post("", response_model=SessionResponse, status_code=201)
async def create_session(
    body: SessionCreateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    session = Session(
        user_id=user.id,
        session_type=body.session_type,
        duration_seconds=body.duration_seconds,
        completed=body.completed,
        mood_before=body.mood_before,
        mood_after=body.mood_after,
        audio_track=body.audio_track,
    )
    db.add(session)

    if body.completed:
        today = date.today()
        user.total_sessions += 1
        user.total_minutes += body.duration_seconds // 60

        if user.last_session_date is not None:
            if user.last_session_date == today - timedelta(days=1):
                user.current_streak += 1
            elif user.last_session_date != today:
                user.current_streak = 1
        else:
            user.current_streak = 1

        user.longest_streak = max(user.longest_streak, user.current_streak)
        user.last_session_date = today

    await db.commit()
    await db.refresh(session)

    return SessionResponse(
        id=session.id,
        session_type=session.session_type,
        duration_seconds=session.duration_seconds,
        completed=session.completed,
        mood_before=session.mood_before,
        mood_after=session.mood_after,
        created_at=session.created_at,
    )


@sessions_router.get("/stats", response_model=StatsResponse)
async def get_stats(user: User = Depends(get_current_user)):
    return StatsResponse(
        total_sessions=user.total_sessions,
        current_streak=user.current_streak,
        longest_streak=user.longest_streak,
        total_minutes=user.total_minutes,
        last_session_date=(
            user.last_session_date.isoformat() if user.last_session_date else None
        ),
    )


# ── Mood ────────────────────────────────────────────────────────────────────

@mood_router.post("", response_model=MoodResponse, status_code=201)
async def create_mood(
    body: MoodCreateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    entry = MoodEntry(
        user_id=user.id,
        emotion=body.emotion,
        intensity=body.intensity,
        note=body.note,
        context=body.context,
    )
    db.add(entry)
    await db.commit()
    await db.refresh(entry)

    return MoodResponse(
        id=entry.id,
        emotion=entry.emotion,
        intensity=entry.intensity,
        note=entry.note,
        context=entry.context,
        ai_insight=entry.ai_insight,
        created_at=entry.created_at,
    )


@mood_router.get("/history", response_model=MoodHistoryResponse)
async def get_mood_history(
    limit: int = 50,
    offset: int = 0,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    total_q = await db.execute(
        select(func.count(MoodEntry.id)).where(MoodEntry.user_id == user.id)
    )
    total = total_q.scalar() or 0

    result = await db.execute(
        select(MoodEntry)
        .where(MoodEntry.user_id == user.id)
        .order_by(desc(MoodEntry.created_at))
        .limit(min(limit, 200))
        .offset(offset)
    )

    return MoodHistoryResponse(
        entries=[
            MoodResponse(
                id=e.id, emotion=e.emotion, intensity=e.intensity,
                note=e.note, context=e.context, ai_insight=e.ai_insight,
                created_at=e.created_at,
            )
            for e in result.scalars().all()
        ],
        total=total,
    )


# ── Companion ───────────────────────────────────────────────────────────────

@companion_router.post("", response_model=CompanionResponse)
async def get_companion(
    body: CompanionRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    engine = CompanionEngine(db)
    data = await engine.get_response(
        user, body.current_mood, body.hour,
        intensity=body.intensity,
        seconds_since_last=body.seconds_since_last_checkin,
    )

    action_data = data.get("action")
    action = ImmediateActionResponse(**action_data) if action_data else None

    return CompanionResponse(
        response_mode=data.get("response_mode", "minimal_verbal"),
        presence=data["presence"],
        insight=data.get("insight"),
        universe_mood=data.get("universe_mood", body.current_mood),
        action=action,
        universe=UniverseResponse(**data["universe"]),
        tone=data["tone"],
        patterns_summary=data.get("patterns_summary"),
        recognition=data.get("recognition"),
        orb_breath_speed=data["orb_breath_speed"],
    )


# ── Meditations catalog ────────────────────────────────────────────────────

@meditations_router.get("")
async def list_meditations(
    category: str | None = None,
    db: AsyncSession = Depends(get_db),
):
    query = select(Meditation)
    if category:
        query = query.where(Meditation.category == category)
    query = query.order_by(desc(Meditation.play_count))

    result = await db.execute(query)
    return [
        {
            "id": m.id, "title": m.title, "description": m.description,
            "category": m.category, "session_type": m.session_type,
            "duration_seconds": m.duration_seconds, "audio_file": m.audio_file,
            "is_premium": m.is_premium,
        }
        for m in result.scalars().all()
    ]


# ── Meditation generation (OpenAI) ─────────────────────────────────────────

@meditations_router.post("/generate", response_model=GenerateMeditationResponse)
async def generate_meditation(
    body: GenerateMeditationRequest,
    user: User = Depends(get_current_user),
):
    if not settings.openai_api_key:
        raise HTTPException(status_code=503, detail="OpenAI not configured")

    system_prompt = (
        "Ты профессиональный ведущий медитаций. "
        "Создай текст медитации на русском: спокойный, уважительный. "
        "Структура: приветствие, настройка дыхания, основная часть, завершение. "
        f"Длительность ~{body.duration_minutes} минут спокойной речи. "
        'Верни JSON: {"title": str, "description": str, "script": str}.'
    )

    try:
        async with httpx.AsyncClient(timeout=120) as client:
            resp = await client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={"Authorization": f"Bearer {settings.openai_api_key}"},
                json={
                    "model": settings.openai_model,
                    "temperature": 0.7,
                    "response_format": {"type": "json_object"},
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": f"Настроение: {body.mood}\nЦель: {body.goal}"},
                    ],
                },
            )
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"OpenAI request failed: {exc}")

    if resp.status_code != 200:
        raise HTTPException(status_code=502, detail="OpenAI error")

    try:
        content = resp.json()["choices"][0]["message"]["content"]
        parsed = json.loads(content)
    except (KeyError, IndexError, json.JSONDecodeError):
        raise HTTPException(status_code=502, detail="Invalid response from AI model")

    return GenerateMeditationResponse(
        title=parsed.get("title", ""),
        description=parsed.get("description", ""),
        script=parsed.get("script", ""),
    )


# ── TTS (ElevenLabs) ───────────────────────────────────────────────────────

@tts_router.post("")
async def text_to_speech(
    body: TTSRequest,
    user: User = Depends(get_current_user),
):
    if not settings.elevenlabs_api_key:
        raise HTTPException(status_code=503, detail="ElevenLabs not configured")

    voice = body.voice_id or settings.elevenlabs_voice_id

    try:
        async with httpx.AsyncClient(timeout=180) as client:
            resp = await client.post(
                f"https://api.elevenlabs.io/v1/text-to-speech/{voice}",
                headers={
                    "xi-api-key": settings.elevenlabs_api_key,
                    "Accept": "audio/mpeg",
                    "Content-Type": "application/json",
                },
                json={"text": body.text, "model_id": settings.elevenlabs_model_id},
            )
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"ElevenLabs request failed: {exc}")

    if resp.status_code != 200:
        raise HTTPException(status_code=502, detail="ElevenLabs error")

    return Response(
        content=resp.content,
        media_type="audio/mpeg",
        headers={"Content-Disposition": "inline"},
    )
