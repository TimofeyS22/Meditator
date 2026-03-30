from fastapi import APIRouter, Depends
from sqlalchemy import delete, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import (
    BiometricSnapshot,
    GardenPlant,
    MoodEntry,
    PairMessage,
    Partnership,
    PasswordResetToken,
    Profile,
    PushToken,
    RefreshToken,
    ScheduledNotification,
    Session,
    Subscription,
)
from app.schemas import ProfileOut, ProfileUpdate

router = APIRouter(prefix="/profiles", tags=["profiles"])


@router.get("/me", response_model=ProfileOut)
async def get_profile(user: Profile = Depends(get_current_user)):
    return ProfileOut.model_validate(user)


@router.put("/me", response_model=ProfileOut)
async def update_profile(
    body: ProfileUpdate,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    data = body.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(user, key, value)
    await db.commit()
    await db.refresh(user)
    return ProfileOut.model_validate(user)


@router.delete("/me", status_code=204)
async def delete_account(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    uid = user.id

    partnership_ids_result = await db.execute(
        select(Partnership.id).where(
            or_(Partnership.user_id == uid, Partnership.partner_id == uid)
        )
    )
    partnership_ids = [row[0] for row in partnership_ids_result.all()]

    if partnership_ids:
        await db.execute(
            delete(PairMessage).where(PairMessage.pair_id.in_(partnership_ids))
        )

    await db.execute(
        delete(Partnership).where(
            or_(Partnership.user_id == uid, Partnership.partner_id == uid)
        )
    )

    await db.execute(delete(BiometricSnapshot).where(BiometricSnapshot.user_id == uid))
    await db.execute(delete(Session).where(Session.user_id == uid))
    await db.execute(delete(MoodEntry).where(MoodEntry.user_id == uid))
    await db.execute(delete(GardenPlant).where(GardenPlant.user_id == uid))
    await db.execute(delete(Subscription).where(Subscription.user_id == uid))
    await db.execute(delete(PushToken).where(PushToken.user_id == uid))
    await db.execute(delete(ScheduledNotification).where(ScheduledNotification.user_id == uid))
    await db.execute(delete(RefreshToken).where(RefreshToken.user_id == uid))
    await db.execute(delete(PasswordResetToken).where(PasswordResetToken.user_id == uid))

    await db.delete(user)
    await db.commit()
