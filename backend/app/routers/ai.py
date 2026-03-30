import json
import uuid as uuid_mod

import httpx
import structlog
from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from fastapi.responses import Response, StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.dependencies import get_current_user
from app.models import Profile
from app.rate_limit import limiter
from app.schemas import (
    AnalyzeMoodRequest,
    AnalyzeMoodResponse,
    GenerateMeditationRequest,
    GenerateMeditationResponse,
    PersonalMeditationRequest,
    PersonalMeditationResponse,
    TranscriptionResponse,
    TtsRequest,
    VoiceMoodResponse,
)
from app.services.context_collector import collect as collect_context

logger = structlog.get_logger()
router = APIRouter(prefix="/ai", tags=["ai"])

OPENAI_URL = f"{settings.openai_base_url}/chat/completions"
WHISPER_URL = f"{settings.openai_base_url}/audio/transcriptions"
ELEVENLABS_URL = "https://api.elevenlabs.io/v1/text-to-speech"
DEFAULT_VOICE_ID = "pNInz6obpgDQGcFmaJgB"
DEFAULT_MODEL_ID = "eleven_multilingual_v2"


async def _openai_chat(system: str, user_content: str) -> dict:
    if not settings.openai_api_key:
        raise HTTPException(status_code=503, detail="OpenAI API key not configured")
    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(
            OPENAI_URL,
            headers={
                "Authorization": f"Bearer {settings.openai_api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": settings.openai_model,
                "temperature": 0.7,
                "response_format": {"type": "json_object"},
                "messages": [
                    {"role": "system", "content": system},
                    {"role": "user", "content": user_content},
                ],
            },
        )
    if resp.status_code != 200:
        logger.error("openai_error", status=resp.status_code, body=resp.text[:500])
        raise HTTPException(status_code=502, detail="OpenAI API error")
    data = resp.json()
    content = data.get("choices", [{}])[0].get("message", {}).get("content", "")
    if not content:
        raise HTTPException(status_code=502, detail="Empty OpenAI response")
    try:
        return json.loads(content)
    except json.JSONDecodeError:
        logger.error("openai_json_parse_failed", raw_content=content[:500])
        raise HTTPException(status_code=502, detail="Failed to parse AI response")


async def _transcribe_upload(file: UploadFile) -> TranscriptionResponse:
    if not settings.openai_api_key:
        raise HTTPException(status_code=503, detail="OpenAI API key not configured")
    audio_bytes = await file.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Empty audio file")
    filename = file.filename or "audio.m4a"
    content_type = file.content_type or "application/octet-stream"
    logger.info("whisper_request", filename=filename, size_bytes=len(audio_bytes))
    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(
            WHISPER_URL,
            headers={"Authorization": f"Bearer {settings.openai_api_key}"},
            files={"file": (filename, audio_bytes, content_type)},
            data={
                "model": "whisper-1",
                "language": "ru",
                "response_format": "verbose_json",
            },
        )
    if resp.status_code != 200:
        logger.error("whisper_error", status=resp.status_code, body=resp.text[:500])
        raise HTTPException(status_code=502, detail="Transcription API error")
    payload = resp.json()
    duration = payload.get("duration")
    if duration is not None:
        try:
            duration = float(duration)
        except (TypeError, ValueError):
            duration = None
    return TranscriptionResponse(
        text=(payload.get("text") or "").strip(),
        language=payload.get("language"),
        duration_seconds=duration,
    )


@router.post("/transcribe", response_model=TranscriptionResponse)
@limiter.limit("10/minute")
async def transcribe(
    request: Request,
    file: UploadFile = File(...),
    _user: Profile = Depends(get_current_user),
):
    result = await _transcribe_upload(file)
    logger.info(
        "transcribe_done",
        text_len=len(result.text),
        language=result.language,
        duration_seconds=result.duration_seconds,
    )
    return result


@router.post("/voice-checkin", response_model=VoiceMoodResponse)
@limiter.limit("5/minute")
async def voice_checkin(
    request: Request,
    file: UploadFile = File(...),
    _user: Profile = Depends(get_current_user),
):
    transcription = await _transcribe_upload(file)
    if not transcription.text:
        logger.warning("voice_checkin_empty_transcript")
        raise HTTPException(status_code=400, detail="No speech detected in audio")
    system = (
        "Ты эмпатичный ассистент для дневника настроения (не клиническая диагностика). "
        "Пользователь продиктовал короткое голосовое сообщение о своём состоянии на русском. "
        "Определи основную эмоцию, до нескольких дополнительных при необходимости, интенсивность целым числом 1–5, "
        "краткое поддерживающее резюме на русском. "
        'Верни ТОЛЬКО JSON: {"primary_emotion": "...", "secondary_emotions": [...], "intensity": <int>, "mood_summary": "..."}'
    )
    parsed = await _openai_chat(system, transcription.text)
    raw_intensity = parsed.get("intensity", 3)
    if isinstance(raw_intensity, bool):
        intensity = 3
    elif isinstance(raw_intensity, int):
        intensity = raw_intensity
    else:
        try:
            intensity = int(float(raw_intensity))
        except (TypeError, ValueError):
            intensity = 3
    intensity = max(1, min(5, intensity))
    secondary = parsed.get("secondary_emotions") or []
    if not isinstance(secondary, list):
        secondary = []
    secondary = [str(x) for x in secondary if x is not None]
    return VoiceMoodResponse(
        text=transcription.text,
        primary_emotion=str(parsed.get("primary_emotion") or "нейтральное"),
        secondary_emotions=secondary,
        intensity=intensity,
        mood_summary=str(parsed.get("mood_summary") or ""),
    )


@router.post("/generate-meditation", response_model=GenerateMeditationResponse)
@limiter.limit("10/minute")
async def generate_meditation(
    request: Request,
    body: GenerateMeditationRequest,
    _user: Profile = Depends(get_current_user),
):
    system = (
        "Ты профессиональный ведущий медитаций и терапевт по релаксации. "
        "Создай полный текст медитации на русском языке: спокойный, уважительный, без панибратства, "
        "без медицинских обещаний и диагнозов. Структура: короткое приветствие, настройка осанки и дыхания, "
        "основная часть под настроение и цель пользователя, мягкое завершение. "
        f"Длительность чтения должна соответствовать примерно {body.duration_minutes} минутам спокойной речи. "
        'Верни ТОЛЬКО валидный JSON: {"title": "...", "description": "...", "script": "..."}'
    )
    parts = [f"Настроение: {body.mood}", f"Цель: {body.goal}", f"Длительность: {body.duration_minutes} мин"]
    if body.user_context:
        parts.append(f"Контекст: {body.user_context}")
    parsed = await _openai_chat(system, "\n".join(parts))
    return GenerateMeditationResponse(
        title=parsed.get("title", ""),
        description=parsed.get("description", ""),
        script=parsed.get("script", ""),
    )


@router.post("/analyze-mood", response_model=AnalyzeMoodResponse)
@limiter.limit("10/minute")
async def analyze_mood(
    request: Request,
    body: AnalyzeMoodRequest,
    _user: Profile = Depends(get_current_user),
):
    system = (
        "Ты психологический аналитик данных самонаблюдения (не клинический диагноз). "
        "Проанализируй дневник настроения на русском языке. "
        "Ищи закономерности: время суток, дни недели, повторяющиеся эмоции, связь с заметками, возможные триггеры. "
        "Не ставь диагнозы. Тон — поддерживающий и конкретный. "
        'Верни ТОЛЬКО JSON: {"patterns": [...], "recommendations": [...], "summary": "..."}'
    )
    entries_text = "\n".join(
        f"- {e.created_at} | {e.emotion} | {e.intensity}/5" + (f" | {e.note}" if e.note else "")
        for e in body.entries
    )
    goals_text = "; ".join(body.user_goals) if body.user_goals else "(не указаны)"
    user_content = f"Цели: {goals_text}\n\nЗаписи:\n{entries_text}"
    parsed = await _openai_chat(system, user_content)
    return AnalyzeMoodResponse(
        patterns=parsed.get("patterns", []),
        recommendations=parsed.get("recommendations", []),
        summary=parsed.get("summary", ""),
    )


@router.post("/tts")
@limiter.limit("10/minute")
async def text_to_speech(
    request: Request,
    body: TtsRequest,
    _user: Profile = Depends(get_current_user),
):
    if not settings.openai_api_key:
        raise HTTPException(status_code=503, detail="OpenAI API key not configured")
    voice = body.voice_id or "nova"
    tts_url = f"{settings.openai_base_url}/audio/speech"
    async with httpx.AsyncClient(timeout=180) as client:
        resp = await client.post(
            tts_url,
            headers={
                "Authorization": f"Bearer {settings.openai_api_key}",
                "Content-Type": "application/json",
            },
            json={"model": "tts-1-hd", "input": body.text[:4096], "voice": voice, "response_format": "mp3"},
        )
    if resp.status_code != 200:
        logger.error("tts_error", status=resp.status_code, body=resp.text[:300])
        raise HTTPException(status_code=502, detail="TTS API error")
    return Response(content=resp.content, media_type="audio/mpeg")


@router.post("/tts-stream")
@limiter.limit("5/minute")
async def tts_stream(
    request: Request,
    body: TtsRequest,
    _user: Profile = Depends(get_current_user),
):
    """Stream TTS audio chunks for low-latency playback."""
    if not settings.openai_api_key:
        raise HTTPException(status_code=503, detail="OpenAI API key not configured")
    voice = body.voice_id or "nova"
    tts_url = f"{settings.openai_base_url}/audio/speech"

    async def _generate():
        async with httpx.AsyncClient(timeout=180) as client:
            async with client.stream(
                "POST",
                tts_url,
                headers={
                    "Authorization": f"Bearer {settings.openai_api_key}",
                    "Content-Type": "application/json",
                },
                json={"model": "tts-1-hd", "input": body.text[:4096], "voice": voice, "response_format": "mp3"},
            ) as resp:
                if resp.status_code != 200:
                    return
                async for chunk in resp.aiter_bytes(4096):
                    yield chunk

    return StreamingResponse(_generate(), media_type="audio/mpeg")


@router.post("/personal-meditation", response_model=PersonalMeditationResponse)
@limiter.limit("5/minute")
async def personal_meditation(
    request: Request,
    body: PersonalMeditationRequest,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Generate a fully personalized meditation: collect context -> generate script -> TTS."""
    ctx = await collect_context(user, db)

    mood_info = body.mood_override or (ctx["recent_moods"][0] if ctx["recent_moods"] else "не указано")
    goals_str = ", ".join(ctx["goals"]) if ctx["goals"] else "общее благополучие"

    system = (
        "Ты профессиональный ведущий медитаций и терапевт по релаксации. "
        "Создай полный текст ПЕРСОНАЛЬНОЙ медитации на русском языке. "
        "Учитывай контекст пользователя: его настроение, цели, время суток, уровень опыта. "
        "Стиль: спокойный, уважительный, без панибратства, без медицинских обещаний. "
        "Структура: приветствие, настройка дыхания, основная часть адаптированная под контекст, завершение. "
        f"Длительность чтения: ~{body.duration_minutes} минут спокойной речи. "
        'Верни ТОЛЬКО JSON: {"title": "...", "description": "...", "script": "..."}'
    )
    user_content = (
        f"Контекст пользователя:\n{ctx['summary']}\n"
        f"Текущее настроение: {mood_info}\n"
        f"Цели: {goals_str}\n"
        f"Длительность: {body.duration_minutes} мин\n"
        f"Предпочитаемый голос: {ctx['preferred_voice']}"
    )

    parsed = await _openai_chat(system, user_content)
    title = parsed.get("title", "Персональная медитация")
    description = parsed.get("description", "")
    script = parsed.get("script", "")

    if not script:
        raise HTTPException(status_code=502, detail="Empty script from AI")

    voice = body.voice or ctx.get("preferred_voice", "nova")
    tts_url = f"{settings.openai_base_url}/audio/speech"
    async with httpx.AsyncClient(timeout=180) as client:
        tts_resp = await client.post(
            tts_url,
            headers={
                "Authorization": f"Bearer {settings.openai_api_key}",
                "Content-Type": "application/json",
            },
            json={"model": "tts-1-hd", "input": script[:4096], "voice": voice, "response_format": "mp3"},
        )
    if tts_resp.status_code != 200:
        logger.error("personal_tts_error", status=tts_resp.status_code)
        raise HTTPException(status_code=502, detail="TTS generation failed")

    from pathlib import Path
    audio_dir = Path(__file__).resolve().parent.parent.parent / "assets" / "audio" / "personal"
    audio_dir.mkdir(parents=True, exist_ok=True)
    file_id = f"personal_{uuid_mod.uuid4().hex[:12]}"
    audio_path = audio_dir / f"{file_id}.mp3"
    audio_path.write_bytes(tts_resp.content)

    return PersonalMeditationResponse(
        title=title,
        description=description,
        script=script,
        audio_url=f"/audio/personal/{file_id}.mp3",
        context_summary=ctx["summary"],
    )


@router.post("/monthly-digest")
@limiter.limit("3/hour")
async def monthly_digest(
    request: Request,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Generate a personalized monthly AI letter from Aura."""
    from app.services.intelligence_engine import build_monthly_summary

    stats = await build_monthly_summary(user.id, db)
    name = stats.get("display_name") or "друг"
    emotions_str = ", ".join(f"{e} ({c})" for e, c in stats.get("top_emotions", []))

    system = (
        "Ты — Аура, AI-компаньон приложения Meditator. "
        "Напиши тёплое, персональное письмо-дайджест за последний месяц. "
        "Тон: заботливый, уважительный, без панибратства, без медицинских обещаний. "
        "Структура: приветствие по имени, обзор практики (сессии, минуты, дни), "
        "наблюдения о настроении, что получается хорошо, мягкая рекомендация на следующий месяц. "
        "Длина: 150-250 слов. Язык: русский. "
        'Верни JSON: {"letter": "текст письма"}'
    )
    user_content = (
        f"Имя: {name}\n"
        f"Сессий за месяц: {stats['total_sessions']}\n"
        f"Минут практики: {stats['total_minutes']}\n"
        f"Дней с практикой: {stats['practice_days']}\n"
        f"Записей настроения: {stats['mood_entries']}\n"
        f"Частые эмоции: {emotions_str or 'нет данных'}\n"
        f"Средняя интенсивность: {stats['avg_intensity']}/5\n"
        f"Стрессовых записей: {stats['stress_entries']}\n"
        f"Текущая серия: {stats['current_streak']} дней\n"
        f"Лучшая серия: {stats['longest_streak']} дней"
    )

    parsed = await _openai_chat(system, user_content)
    letter = parsed.get("letter", "")

    return {"letter": letter, "stats": stats}
