import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import Course, CourseDay, CourseProgress, Profile

router = APIRouter(prefix="/courses", tags=["courses"])
logger = structlog.get_logger()


class CourseDayOut(BaseModel):
    day_number: int
    title: str
    meditation_id: str | None = None
    duration_minutes: int = 10

    model_config = {"from_attributes": True}


class CourseOut(BaseModel):
    id: str
    title: str
    description: str | None = None
    duration_days: int
    category: str
    image_url: str | None = None
    is_premium: bool = False
    days: list[CourseDayOut] = []
    user_progress: int = 0

    model_config = {"from_attributes": True}


class EnrollRequest(BaseModel):
    course_id: str


class ProgressUpdate(BaseModel):
    course_id: str
    day_number: int


@router.get("", response_model=list[CourseOut])
async def list_courses(
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Course).order_by(Course.sort_order, Course.created_at)
    )
    courses = result.scalars().all()
    out = []
    for c in courses:
        days_result = await db.execute(
            select(CourseDay)
            .where(CourseDay.course_id == c.id)
            .order_by(CourseDay.day_number)
        )
        days = days_result.scalars().all()

        prog_result = await db.execute(
            select(CourseProgress).where(
                CourseProgress.user_id == user.id,
                CourseProgress.course_id == c.id,
            )
        )
        prog = prog_result.scalar_one_or_none()

        out.append(CourseOut(
            id=c.id,
            title=c.title,
            description=c.description,
            duration_days=c.duration_days,
            category=c.category,
            image_url=c.image_url,
            is_premium=c.is_premium,
            days=[CourseDayOut.model_validate(d) for d in days],
            user_progress=prog.last_completed_day if prog else 0,
        ))
    return out


@router.get("/{course_id}", response_model=CourseOut)
async def get_course(
    course_id: str,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Course).where(Course.id == course_id))
    course = result.scalar_one_or_none()
    if not course:
        raise HTTPException(status_code=404, detail="Course not found")

    days_result = await db.execute(
        select(CourseDay)
        .where(CourseDay.course_id == course_id)
        .order_by(CourseDay.day_number)
    )
    days = days_result.scalars().all()

    prog_result = await db.execute(
        select(CourseProgress).where(
            CourseProgress.user_id == user.id,
            CourseProgress.course_id == course_id,
        )
    )
    prog = prog_result.scalar_one_or_none()

    return CourseOut(
        id=course.id,
        title=course.title,
        description=course.description,
        duration_days=course.duration_days,
        category=course.category,
        image_url=course.image_url,
        is_premium=course.is_premium,
        days=[CourseDayOut.model_validate(d) for d in days],
        user_progress=prog.last_completed_day if prog else 0,
    )


@router.post("/enroll", status_code=201)
async def enroll_in_course(
    body: EnrollRequest,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    existing = await db.execute(
        select(CourseProgress).where(
            CourseProgress.user_id == user.id,
            CourseProgress.course_id == body.course_id,
        )
    )
    if existing.scalar_one_or_none():
        return {"status": "already_enrolled"}

    db.add(CourseProgress(user_id=user.id, course_id=body.course_id))
    await db.commit()
    return {"status": "enrolled"}


@router.post("/progress", status_code=200)
async def update_progress(
    body: ProgressUpdate,
    user: Profile = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(CourseProgress).where(
            CourseProgress.user_id == user.id,
            CourseProgress.course_id == body.course_id,
        )
    )
    prog = result.scalar_one_or_none()
    if not prog:
        prog = CourseProgress(user_id=user.id, course_id=body.course_id)
        db.add(prog)

    if body.day_number > prog.last_completed_day:
        prog.last_completed_day = body.day_number

    course_result = await db.execute(
        select(Course).where(Course.id == body.course_id)
    )
    course = course_result.scalar_one_or_none()
    if course and prog.last_completed_day >= course.duration_days:
        from datetime import datetime, timezone
        prog.completed_at = datetime.now(timezone.utc)

    await db.commit()
    return {"last_completed_day": prog.last_completed_day}
