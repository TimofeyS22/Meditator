from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Meditation
from app.schemas import MeditationOut

router = APIRouter(prefix="/meditations", tags=["meditations"])


@router.get("", response_model=list[MeditationOut])
async def list_meditations(
    category: str | None = None,
    limit: int = Query(default=100, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
):
    q = select(Meditation)
    if category:
        q = q.where(Meditation.category == category)
    q = q.limit(limit)
    result = await db.execute(q)
    return [MeditationOut.model_validate(r) for r in result.scalars().all()]


@router.get("/{meditation_id}", response_model=MeditationOut)
async def get_meditation(meditation_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Meditation).where(Meditation.id == meditation_id))
    med = result.scalar_one_or_none()
    if not med:
        raise HTTPException(status_code=404, detail="Meditation not found")
    return MeditationOut.model_validate(med)
