from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import MoodEntry, Profile
from app.schemas import InsightUpdate, MoodEntryCreate, MoodEntryOut

router = APIRouter(prefix="/mood-entries", tags=["mood-entries"])


@router.post("", response_model=MoodEntryOut, status_code=201)
async def create_mood_entry(
    body: MoodEntryCreate,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    entry = MoodEntry(
        user_id=user.id,
        primary_emotion=body.primary_emotion,
        secondary_emotions=body.secondary_emotions,
        intensity=body.intensity,
        note=body.note,
    )
    db.add(entry)
    await db.commit()
    await db.refresh(entry)
    return MoodEntryOut.model_validate(entry)


@router.get("", response_model=list[MoodEntryOut])
async def list_mood_entries(
    limit: int = Query(default=50, ge=1, le=200),
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    q = (
        select(MoodEntry)
        .where(MoodEntry.user_id == user.id)
        .order_by(MoodEntry.created_at.desc())
        .limit(limit)
    )
    result = await db.execute(q)
    return [MoodEntryOut.model_validate(r) for r in result.scalars().all()]


@router.delete("/{entry_id}", status_code=204)
async def delete_mood_entry(
    entry_id: str,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MoodEntry).where(MoodEntry.id == entry_id, MoodEntry.user_id == user.id)
    )
    entry = result.scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404, detail="Entry not found")
    await db.delete(entry)
    await db.commit()


@router.patch("/{entry_id}/insight", response_model=MoodEntryOut)
async def update_insight(
    entry_id: str,
    body: InsightUpdate,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MoodEntry).where(MoodEntry.id == entry_id, MoodEntry.user_id == user.id)
    )
    entry = result.scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404, detail="Entry not found")
    entry.ai_insight = body.ai_insight
    await db.commit()
    await db.refresh(entry)
    return MoodEntryOut.model_validate(entry)
