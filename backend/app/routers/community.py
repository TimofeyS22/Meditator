import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import (
    Challenge,
    ChallengeParticipation,
    CommunityGroup,
    GroupMembership,
    Profile,
    Session,
)

router = APIRouter(prefix="/community", tags=["community"])
logger = structlog.get_logger()


class ChallengeOut(BaseModel):
    id: str
    title: str
    description: str | None = None
    duration_days: int
    participant_count: int = 0
    icon: str | None = None
    joined: bool = False
    days_completed: int = 0

    model_config = {"from_attributes": True}


class GroupOut(BaseModel):
    id: str
    name: str
    description: str | None = None
    image_url: str | None = None
    member_count: int = 0
    is_member: bool = False

    model_config = {"from_attributes": True}


class LeaderboardEntry(BaseModel):
    rank: int
    display_name: str
    total_minutes: int
    current_streak: int
    is_current_user: bool = False


class JoinChallengeRequest(BaseModel):
    challenge_id: str


class JoinGroupRequest(BaseModel):
    group_id: str


@router.get("/challenges", response_model=list[ChallengeOut])
async def list_challenges(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Challenge).where(Challenge.is_active.is_(True)).order_by(Challenge.created_at.desc())
    )
    challenges = result.scalars().all()
    out = []
    for c in challenges:
        part_result = await db.execute(
            select(ChallengeParticipation).where(
                ChallengeParticipation.challenge_id == c.id,
                ChallengeParticipation.user_id == user.id,
            )
        )
        part = part_result.scalar_one_or_none()
        out.append(ChallengeOut(
            id=str(c.id),
            title=c.title,
            description=c.description,
            duration_days=c.duration_days,
            participant_count=c.participant_count,
            icon=c.icon,
            joined=part is not None,
            days_completed=part.days_completed if part else 0,
        ))
    return out


@router.post("/challenges/join", status_code=201)
async def join_challenge(
    body: JoinChallengeRequest,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    import uuid
    challenge_id = uuid.UUID(body.challenge_id)

    existing = await db.execute(
        select(ChallengeParticipation).where(
            ChallengeParticipation.challenge_id == challenge_id,
            ChallengeParticipation.user_id == user.id,
        )
    )
    if existing.scalar_one_or_none():
        return {"status": "already_joined"}

    challenge_result = await db.execute(
        select(Challenge).where(Challenge.id == challenge_id)
    )
    challenge = challenge_result.scalar_one_or_none()
    if not challenge:
        raise HTTPException(status_code=404, detail="Challenge not found")

    db.add(ChallengeParticipation(challenge_id=challenge_id, user_id=user.id))
    challenge.participant_count += 1
    await db.commit()
    return {"status": "joined"}


@router.get("/groups", response_model=list[GroupOut])
async def list_groups(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(CommunityGroup).order_by(CommunityGroup.member_count.desc())
    )
    groups = result.scalars().all()
    out = []
    for g in groups:
        mem_result = await db.execute(
            select(GroupMembership).where(
                GroupMembership.group_id == g.id,
                GroupMembership.user_id == user.id,
            )
        )
        is_member = mem_result.scalar_one_or_none() is not None
        out.append(GroupOut(
            id=str(g.id),
            name=g.name,
            description=g.description,
            image_url=g.image_url,
            member_count=g.member_count,
            is_member=is_member,
        ))
    return out


@router.post("/groups/join", status_code=201)
async def join_group(
    body: JoinGroupRequest,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    import uuid
    group_id = uuid.UUID(body.group_id)

    existing = await db.execute(
        select(GroupMembership).where(
            GroupMembership.group_id == group_id,
            GroupMembership.user_id == user.id,
        )
    )
    if existing.scalar_one_or_none():
        return {"status": "already_member"}

    group_result = await db.execute(
        select(CommunityGroup).where(CommunityGroup.id == group_id)
    )
    group = group_result.scalar_one_or_none()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")

    db.add(GroupMembership(group_id=group_id, user_id=user.id))
    group.member_count += 1
    await db.commit()
    return {"status": "joined"}


@router.get("/leaderboard", response_model=list[LeaderboardEntry])
async def get_leaderboard(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Profile)
        .order_by(Profile.total_minutes.desc())
        .limit(50)
    )
    profiles = result.scalars().all()
    out = []
    for i, p in enumerate(profiles):
        name = p.display_name or f"Медитатор-{str(p.id)[-4:]}"
        if p.id != user.id:
            name = f"Медитатор-{str(p.id)[-4:]}"
        out.append(LeaderboardEntry(
            rank=i + 1,
            display_name=name,
            total_minutes=p.total_minutes or 0,
            current_streak=p.current_streak or 0,
            is_current_user=p.id == user.id,
        ))
    return out
