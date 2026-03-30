import structlog
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import Partnership, Profile
from app.schemas import PartnershipCreate, PartnershipOut, PartnershipUpdate

logger = structlog.get_logger()
router = APIRouter(prefix="/partnerships", tags=["partnerships"])


@router.get("", response_model=PartnershipOut | None)
async def get_partnership(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    q = select(Partnership).where(
        or_(Partnership.user_id == user.id, Partnership.partner_id == user.id)
    ).limit(1)
    result = await db.execute(q)
    row = result.scalars().first()
    return PartnershipOut.model_validate(row) if row else None


@router.post("", response_model=PartnershipOut, status_code=201)
async def create_partnership(
    body: PartnershipCreate,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if body.partner_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot partner with yourself")

    partner_exists = await db.execute(select(Profile.id).where(Profile.id == body.partner_id))
    if not partner_exists.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Partner user not found")

    p = Partnership(
        user_id=user.id,
        partner_id=body.partner_id,
        partner_name=body.partner_name,
        shared_goals=body.shared_goals,
    )
    db.add(p)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=409, detail="Partnership already exists")
    await db.refresh(p)

    logger.info("partnership_created", user_id=str(user.id), partner_id=str(body.partner_id))
    return PartnershipOut.model_validate(p)


@router.patch("/{partnership_id}", response_model=PartnershipOut)
async def update_partnership(
    partnership_id: str,
    body: PartnershipUpdate,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Partnership).where(
            Partnership.id == partnership_id,
            or_(Partnership.user_id == user.id, Partnership.partner_id == user.id),
        )
    )
    p = result.scalars().first()
    if not p:
        raise HTTPException(status_code=404, detail="Partnership not found")
    for key, val in body.model_dump(exclude_unset=True).items():
        setattr(p, key, val)
    await db.commit()
    await db.refresh(p)
    return PartnershipOut.model_validate(p)
