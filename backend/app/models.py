import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB, UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

from pgvector.sqlalchemy import Vector


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Base(DeclarativeBase):
    pass


class Profile(Base):
    __tablename__ = "profiles"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email: Mapped[str | None] = mapped_column(Text, unique=True)
    display_name: Mapped[str | None] = mapped_column(Text)
    avatar_url: Mapped[str | None] = mapped_column(Text)
    password_hash: Mapped[str] = mapped_column(Text, nullable=False, default="")
    goals: Mapped[list[str]] = mapped_column(ARRAY(String), default=list)
    stress_level: Mapped[str | None] = mapped_column(Text)
    preferred_duration: Mapped[str | None] = mapped_column(Text)
    preferred_voice: Mapped[str | None] = mapped_column(Text)
    preferred_time_hour: Mapped[int | None] = mapped_column(Integer)
    is_premium: Mapped[bool] = mapped_column(Boolean, default=False)
    total_sessions: Mapped[int] = mapped_column(Integer, default=0)
    current_streak: Mapped[int] = mapped_column(Integer, default=0)
    longest_streak: Mapped[int] = mapped_column(Integer, default=0)
    total_minutes: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)


class Meditation(Base):
    __tablename__ = "meditations"

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    title: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    category: Mapped[str] = mapped_column(Text, nullable=False)
    duration_minutes: Mapped[int] = mapped_column(Integer, nullable=False)
    audio_url: Mapped[str | None] = mapped_column(Text)
    image_url: Mapped[str | None] = mapped_column(Text)
    is_generated: Mapped[bool] = mapped_column(Boolean, default=False)
    is_premium: Mapped[bool] = mapped_column(Boolean, default=False)
    voice_name: Mapped[str | None] = mapped_column(Text)
    rating: Mapped[float | None] = mapped_column(Numeric(3, 2))
    play_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    __table_args__ = (Index("ix_meditations_category", "category"),)


class Session(Base):
    __tablename__ = "sessions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    meditation_id: Mapped[str | None] = mapped_column(Text, ForeignKey("meditations.id", ondelete="SET NULL"))
    duration_seconds: Mapped[int] = mapped_column(Integer, default=0)
    completed: Mapped[bool] = mapped_column(Boolean, default=False)
    mood_before: Mapped[str | None] = mapped_column(Text)
    mood_after: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    __table_args__ = (Index("ix_sessions_user_created", "user_id", "created_at"),)


class BiometricSnapshot(Base):
    __tablename__ = "biometric_snapshots"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False
    )
    session_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("sessions.id", ondelete="SET NULL"), nullable=True
    )
    snapshot_type: Mapped[str] = mapped_column(String(20), nullable=False)
    heart_rate: Mapped[float | None] = mapped_column(Numeric, nullable=True)
    hrv: Mapped[float | None] = mapped_column(Numeric, nullable=True)
    steps_today: Mapped[int | None] = mapped_column(Integer, nullable=True)
    sleep_hours: Mapped[float | None] = mapped_column(Numeric, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    __table_args__ = (Index("ix_biometric_snapshots_user_created", "user_id", "created_at"),)


class MoodEntry(Base):
    __tablename__ = "mood_entries"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    primary_emotion: Mapped[str] = mapped_column(Text, nullable=False)
    secondary_emotions: Mapped[list[str]] = mapped_column(ARRAY(String), default=list)
    intensity: Mapped[int] = mapped_column(Integer, nullable=False)
    note: Mapped[str | None] = mapped_column(Text)
    ai_insight: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    __table_args__ = (
        CheckConstraint("intensity >= 1 AND intensity <= 5"),
        Index("ix_mood_entries_user_created", "user_id", "created_at"),
    )


class GardenPlant(Base):
    __tablename__ = "garden_plants"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    type: Mapped[str] = mapped_column(Text, nullable=False)
    stage: Mapped[str] = mapped_column(Text, nullable=False)
    water_count: Mapped[int] = mapped_column(Integer, default=0)
    health_level: Mapped[float] = mapped_column(Numeric(5, 2), default=100)
    pos_x: Mapped[float] = mapped_column(Numeric(10, 4), default=0)
    pos_y: Mapped[float] = mapped_column(Numeric(10, 4), default=0)
    planted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    last_watered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    __table_args__ = (Index("ix_garden_plants_user", "user_id"),)


class Partnership(Base):
    __tablename__ = "partnerships"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    partner_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    partner_name: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(Text, default="pending")
    shared_goals: Mapped[list[str]] = mapped_column(ARRAY(String), default=list)
    my_streak: Mapped[int] = mapped_column(Integer, default=0)
    partner_streak: Mapped[int] = mapped_column(Integer, default=0)
    shared_sessions: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    __table_args__ = (
        CheckConstraint("user_id != partner_id", name="partnerships_no_self"),
        UniqueConstraint("user_id", "partner_id", name="partnerships_user_partner_unique"),
    )


class PairMessage(Base):
    __tablename__ = "pair_messages"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    pair_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("partnerships.id", ondelete="CASCADE"), nullable=False)
    sender_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    type: Mapped[str] = mapped_column(Text, default="text")
    content: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    __table_args__ = (Index("ix_pair_messages_pair_created", "pair_id", "created_at"),)


class PasswordResetToken(Base):
    __tablename__ = "password_reset_tokens"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    token: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    used: Mapped[bool] = mapped_column(Boolean, default=False)

    __table_args__ = (Index("ix_password_reset_tokens_user", "user_id"),)


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    jti: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    family: Mapped[str] = mapped_column(Text, nullable=False, index=True)
    revoked: Mapped[bool] = mapped_column(Boolean, default=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    __table_args__ = (Index("ix_refresh_tokens_user", "user_id"),)


class Subscription(Base):
    __tablename__ = "subscriptions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    plan: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(Text, nullable=False, default="active")
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    payment_id: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    __table_args__ = (
        CheckConstraint("plan IN ('monthly', 'yearly')", name="subscriptions_plan_check"),
        CheckConstraint("status IN ('active', 'cancelled', 'expired')", name="subscriptions_status_check"),
        Index("ix_subscriptions_user", "user_id"),
    )


class KnowledgeChunk(Base):
    __tablename__ = "knowledge_chunks"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    source: Mapped[str] = mapped_column(Text, nullable=False)
    category: Mapped[str] = mapped_column(Text, nullable=False)
    language: Mapped[str] = mapped_column(Text, nullable=False, default="ru")
    embedding = mapped_column(Vector(1536))
    metadata_: Mapped[dict | None] = mapped_column(JSONB)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    __table_args__ = (Index("ix_knowledge_chunks_category", "category"),)


class PushToken(Base):
    __tablename__ = "push_tokens"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False
    )
    token: Mapped[str] = mapped_column(String(512), nullable=False)
    platform: Mapped[str] = mapped_column(String(20), default="ios")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    __table_args__ = (UniqueConstraint("user_id", "token", name="uq_push_token"),)


class Course(Base):
    __tablename__ = "courses"

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    title: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    duration_days: Mapped[int] = mapped_column(Integer, nullable=False)
    category: Mapped[str] = mapped_column(Text, nullable=False)
    image_url: Mapped[str | None] = mapped_column(Text)
    is_premium: Mapped[bool] = mapped_column(Boolean, default=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)


class CourseDay(Base):
    __tablename__ = "course_days"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    course_id: Mapped[str] = mapped_column(Text, ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    day_number: Mapped[int] = mapped_column(Integer, nullable=False)
    title: Mapped[str] = mapped_column(Text, nullable=False)
    meditation_id: Mapped[str | None] = mapped_column(Text, ForeignKey("meditations.id", ondelete="SET NULL"))
    duration_minutes: Mapped[int] = mapped_column(Integer, default=10)

    __table_args__ = (
        UniqueConstraint("course_id", "day_number", name="uq_course_day"),
        Index("ix_course_days_course", "course_id"),
    )


class CourseProgress(Base):
    __tablename__ = "course_progress"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    course_id: Mapped[str] = mapped_column(Text, ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    last_completed_day: Mapped[int] = mapped_column(Integer, default=0)
    enrolled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    __table_args__ = (
        UniqueConstraint("user_id", "course_id", name="uq_user_course"),
        Index("ix_course_progress_user", "user_id"),
    )


class CommunityGroup(Base):
    __tablename__ = "community_groups"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    image_url: Mapped[str | None] = mapped_column(Text)
    member_count: Mapped[int] = mapped_column(Integer, default=0)
    created_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="SET NULL"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)


class GroupMembership(Base):
    __tablename__ = "group_memberships"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    group_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("community_groups.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    __table_args__ = (
        UniqueConstraint("group_id", "user_id", name="uq_group_member"),
    )


class Challenge(Base):
    __tablename__ = "challenges"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    duration_days: Mapped[int] = mapped_column(Integer, nullable=False)
    participant_count: Mapped[int] = mapped_column(Integer, default=0)
    icon: Mapped[str | None] = mapped_column(String(50))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)


class ChallengeParticipation(Base):
    __tablename__ = "challenge_participations"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    challenge_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("challenges.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    days_completed: Mapped[int] = mapped_column(Integer, default=0)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    __table_args__ = (
        UniqueConstraint("challenge_id", "user_id", name="uq_challenge_user"),
    )


class ScheduledNotification(Base):
    __tablename__ = "scheduled_notifications"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    action_type: Mapped[str] = mapped_column(String(50), default="micro_intervention")
    action_data: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    scheduled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    sent: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
