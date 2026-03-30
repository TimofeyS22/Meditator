import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import BiometricSnapshot, Profile, Session
from app.rate_limit import limiter
from app.routers.ai import _openai_chat
from app.schemas import BiometricSnapshotCreate, BiometricSnapshotOut, SessionContextResponse

logger = structlog.get_logger()
router = APIRouter(prefix="/biometrics", tags=["biometrics"])

_INTENSITY_ALLOWED = frozenset({"gentle", "moderate", "deep"})


async def _require_owned_session(
    db: AsyncSession, user_id, session_id,
) -> None:
    if session_id is None:
        return
    r = await db.execute(
        select(Session).where(Session.id == session_id, Session.user_id == user_id)
    )
    if r.scalar_one_or_none() is None:
        raise HTTPException(status_code=404, detail="Session not found")


def _snapshot_from_body(user_id, body: BiometricSnapshotCreate) -> BiometricSnapshot:
    return BiometricSnapshot(
        user_id=user_id,
        session_id=body.session_id,
        snapshot_type=body.snapshot_type,
        heart_rate=body.heart_rate,
        hrv=body.hrv,
        steps_today=body.steps_today,
        sleep_hours=body.sleep_hours,
    )


def _parse_session_context(parsed: dict) -> SessionContextResponse:
    raw_dur = parsed.get("recommended_duration", 10)
    try:
        duration = int(float(raw_dur))
    except (TypeError, ValueError):
        duration = 10
    duration = max(3, min(60, duration))

    category = str(parsed.get("recommended_category") or "general").strip() or "general"

    intensity = str(parsed.get("intensity") or "moderate").strip().lower()
    if intensity not in _INTENSITY_ALLOWED:
        intensity = "moderate"

    reasoning = str(parsed.get("reasoning") or "").strip()
    if not reasoning:
        reasoning = "Рекомендация сформирована по доступным биометрическим данным."

    return SessionContextResponse(
        recommended_duration=duration,
        recommended_category=category,
        intensity=intensity,
        reasoning=reasoning,
    )


@router.post("", response_model=BiometricSnapshotOut, status_code=201)
async def create_biometric_snapshot(
    body: BiometricSnapshotCreate,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _require_owned_session(db, user.id, body.session_id)
    row = _snapshot_from_body(user.id, body)
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return BiometricSnapshotOut.model_validate(row)


@router.get("", response_model=list[BiometricSnapshotOut])
async def list_biometric_snapshots(
    limit: int = Query(default=10, ge=1, le=200),
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    q = (
        select(BiometricSnapshot)
        .where(BiometricSnapshot.user_id == user.id)
        .order_by(BiometricSnapshot.created_at.desc())
        .limit(limit)
    )
    result = await db.execute(q)
    return [BiometricSnapshotOut.model_validate(r) for r in result.scalars().all()]


@router.post("/session-context", response_model=SessionContextResponse)
@limiter.limit("10/minute")
async def session_context(
    request: Request,
    body: BiometricSnapshotCreate,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _require_owned_session(db, user.id, body.session_id)
    row = _snapshot_from_body(user.id, body)
    db.add(row)
    await db.commit()
    await db.refresh(row)

    parts = [
        f"snapshot_type: {body.snapshot_type}",
        f"heart_rate: {body.heart_rate}",
        f"hrv: {body.hrv}",
        f"steps_today: {body.steps_today}",
        f"sleep_hours: {body.sleep_hours}",
    ]
    user_content = "\n".join(parts)

    system = (
        "You are a supportive meditation and wellness coach (not a doctor; no diagnoses). "
        "Given the user's biometric snapshot, recommend a single meditation plan. "
        "recommended_duration: integer minutes between 3 and 60. "
        "recommended_category: short English slug matching common meditation types "
        "(e.g. sleep, stress_relief, focus, breathing, body_scan, anxiety, energy). "
        "intensity: exactly one of gentle, moderate, deep. "
        "reasoning: 1-3 sentences in Russian, empathetic and practical. "
        'Return ONLY JSON: {"recommended_duration": <int>, "recommended_category": "<str>", '
        '"intensity": "<gentle|moderate|deep>", "reasoning": "<str>"}'
    )

    parsed = await _openai_chat(system, user_content)
    out = _parse_session_context(parsed)
    logger.info(
        "session_context_done",
        user_id=str(user.id),
        snapshot_id=str(row.id),
        duration=out.recommended_duration,
        category=out.recommended_category,
        intensity=out.intensity,
    )
    return out
