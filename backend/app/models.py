import uuid
from datetime import datetime, date

from sqlalchemy import (
    String, Integer, Float, Boolean, Text, DateTime, Date,
    ForeignKey, func, Index,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    display_name: Mapped[str] = mapped_column(String(100), default="")

    is_premium: Mapped[bool] = mapped_column(Boolean, default=False)
    premium_expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    total_sessions: Mapped[int] = mapped_column(Integer, default=0)
    current_streak: Mapped[int] = mapped_column(Integer, default=0)
    longest_streak: Mapped[int] = mapped_column(Integer, default=0)
    total_minutes: Mapped[int] = mapped_column(Integer, default=0)
    last_session_date: Mapped[date | None] = mapped_column(Date, nullable=True)

    preferred_duration: Mapped[int] = mapped_column(Integer, default=60)
    notification_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    notification_hour: Mapped[int] = mapped_column(Integer, default=9)

    companion_tone: Mapped[str] = mapped_column(String(50), default="gentle_encouraging")
    dominant_emotion: Mapped[str | None] = mapped_column(String(50), nullable=True)
    emotional_trend: Mapped[str] = mapped_column(String(20), default="stable")
    calm_ratio: Mapped[float] = mapped_column(Float, default=0.0)
    effective_session_types: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), onupdate=func.now(),
    )

    sessions: Mapped[list["Session"]] = relationship(
        back_populates="user", cascade="all, delete-orphan",
    )
    mood_entries: Mapped[list["MoodEntry"]] = relationship(
        back_populates="user", cascade="all, delete-orphan",
    )


class Session(Base):
    __tablename__ = "sessions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True,
    )
    session_type: Mapped[str] = mapped_column(String(50))
    duration_seconds: Mapped[int] = mapped_column(Integer)
    completed: Mapped[bool] = mapped_column(Boolean, default=False)
    mood_before: Mapped[str | None] = mapped_column(String(50), nullable=True)
    mood_after: Mapped[str | None] = mapped_column(String(50), nullable=True)
    audio_track: Mapped[str | None] = mapped_column(String(200), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    user: Mapped["User"] = relationship(back_populates="sessions")

    __table_args__ = (
        Index("idx_sessions_user_created", "user_id", "created_at"),
    )


class MoodEntry(Base):
    __tablename__ = "mood_entries"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True,
    )
    emotion: Mapped[str] = mapped_column(String(50))
    intensity: Mapped[int] = mapped_column(Integer, default=3)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    context: Mapped[str | None] = mapped_column(String(50), nullable=True)
    ai_insight: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    user: Mapped["User"] = relationship(back_populates="mood_entries")

    __table_args__ = (
        Index("idx_mood_user_created", "user_id", "created_at"),
    )


class CompanionMemory(Base):
    __tablename__ = "companion_memory"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True,
    )
    memory_type: Mapped[str] = mapped_column(String(50))
    key: Mapped[str] = mapped_column(String(200))
    value: Mapped[str] = mapped_column(Text)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, server_default=func.now(), onupdate=func.now(),
    )

    __table_args__ = (
        Index("idx_memory_user_type_key", "user_id", "memory_type", "key", unique=True),
    )


class Meditation(Base):
    __tablename__ = "meditations_catalog"

    id: Mapped[str] = mapped_column(String(100), primary_key=True)
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(Text, default="")
    category: Mapped[str] = mapped_column(String(50), index=True)
    session_type: Mapped[str] = mapped_column(String(50), index=True)
    duration_seconds: Mapped[int] = mapped_column(Integer)
    audio_file: Mapped[str] = mapped_column(String(200))
    is_premium: Mapped[bool] = mapped_column(Boolean, default=False)
    play_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
