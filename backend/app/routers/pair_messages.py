from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import PairMessage, Partnership, Profile
from app.schemas import PairMessageCreate, PairMessageOut

router = APIRouter(prefix="/pair-messages", tags=["pair-messages"])


@router.get("", response_model=list[PairMessageOut])
async def list_messages(
    pair_id: str,
    limit: int = Query(default=50, ge=1, le=200),
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    ownership = await db.execute(
        select(Partnership).where(
            Partnership.id == pair_id,
            or_(Partnership.user_id == user.id, Partnership.partner_id == user.id),
        )
    )
    if not ownership.scalars().first():
        raise HTTPException(status_code=403, detail="Not a member of this partnership")

    q = (
        select(PairMessage)
        .where(PairMessage.pair_id == pair_id)
        .order_by(PairMessage.created_at.desc())
        .limit(limit)
    )
    result = await db.execute(q)
    return [PairMessageOut.model_validate(r) for r in result.scalars().all()]


@router.post("", response_model=PairMessageOut, status_code=201)
async def create_message(
    body: PairMessageCreate,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    ownership = await db.execute(
        select(Partnership).where(
            Partnership.id == body.pair_id,
            or_(Partnership.user_id == user.id, Partnership.partner_id == user.id),
        )
    )
    if not ownership.scalars().first():
        raise HTTPException(status_code=403, detail="Not a member of this partnership")

    msg = PairMessage(
        pair_id=body.pair_id,
        sender_id=user.id,
        type=body.type,
        content=body.content,
    )
    db.add(msg)
    await db.commit()
    await db.refresh(msg)
    return PairMessageOut.model_validate(msg)
