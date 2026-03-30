from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import GardenPlant, Profile
from app.schemas import PlantCreate, PlantOut, PlantUpdate

router = APIRouter(prefix="/garden-plants", tags=["garden"])


@router.get("", response_model=list[PlantOut])
async def list_plants(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    q = select(GardenPlant).where(GardenPlant.user_id == user.id).order_by(GardenPlant.planted_at)
    result = await db.execute(q)
    return [PlantOut.model_validate(r) for r in result.scalars().all()]


@router.post("", response_model=PlantOut, status_code=201)
async def create_plant(
    body: PlantCreate,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    plant = GardenPlant(
        user_id=user.id,
        type=body.type,
        stage=body.stage,
        pos_x=body.pos_x,
        pos_y=body.pos_y,
    )
    db.add(plant)
    await db.commit()
    await db.refresh(plant)
    return PlantOut.model_validate(plant)


@router.patch("/{plant_id}", response_model=PlantOut)
async def update_plant(
    plant_id: str,
    body: PlantUpdate,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(GardenPlant).where(GardenPlant.id == plant_id, GardenPlant.user_id == user.id)
    )
    plant = result.scalar_one_or_none()
    if not plant:
        raise HTTPException(status_code=404, detail="Plant not found")
    for key, val in body.model_dump(exclude_unset=True).items():
        setattr(plant, key, val)
    await db.commit()
    await db.refresh(plant)
    return PlantOut.model_validate(plant)
