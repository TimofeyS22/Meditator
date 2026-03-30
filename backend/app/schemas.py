from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


# ── Auth ─────────────────────────────────────────────────────────────────────

class SignUpRequest(BaseModel):
    email: EmailStr = Field(max_length=320)
    password: str = Field(min_length=6, max_length=72)
    display_name: str | None = Field(default=None, max_length=100)

class SignInRequest(BaseModel):
    email: EmailStr = Field(max_length=320)
    password: str = Field(max_length=72)

class RefreshRequest(BaseModel):
    refresh_token: str

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class UserOut(BaseModel):
    id: UUID
    email: str | None
    display_name: str | None

    model_config = {"from_attributes": True}

class AuthResponse(BaseModel):
    user: UserOut
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str = Field(min_length=1, max_length=256)
    new_password: str = Field(min_length=6, max_length=72)


# ── Profiles ─────────────────────────────────────────────────────────────────

class ProfileOut(BaseModel):
    id: UUID
    email: str | None = None
    display_name: str | None = None
    avatar_url: str | None = None
    goals: list[str] = []
    stress_level: str | None = None
    preferred_duration: str | None = None
    preferred_voice: str | None = None
    preferred_time_hour: int | None = None
    is_premium: bool = False
    total_sessions: int = 0
    current_streak: int = 0
    longest_streak: int = 0
    total_minutes: int = 0
    created_at: datetime | None = None
    updated_at: datetime | None = None

    model_config = {"from_attributes": True}

class ProfileUpdate(BaseModel):
    display_name: str | None = Field(default=None, max_length=100)
    avatar_url: str | None = Field(default=None, max_length=2048)
    goals: list[str] | None = Field(default=None, max_length=20)
    stress_level: str | None = Field(default=None, max_length=50)
    preferred_duration: str | None = Field(default=None, max_length=50)
    preferred_voice: str | None = Field(default=None, max_length=50)
    preferred_time_hour: int | None = Field(default=None, ge=0, le=23)


# ── Meditations ──────────────────────────────────────────────────────────────

class MeditationOut(BaseModel):
    id: str
    title: str
    description: str | None = None
    category: str
    duration_minutes: int
    audio_url: str | None = None
    image_url: str | None = None
    is_generated: bool = False
    is_premium: bool = False
    voice_name: str | None = None
    rating: float | None = None
    play_count: int = 0
    created_at: datetime | None = None

    model_config = {"from_attributes": True}


# ── Sessions ─────────────────────────────────────────────────────────────────

class SessionCreate(BaseModel):
    meditation_id: str | None = None
    duration_seconds: int = Field(default=0, ge=0, le=86400)
    completed: bool = False
    mood_before: str | None = Field(default=None, max_length=100)
    mood_after: str | None = Field(default=None, max_length=100)

class SessionOut(BaseModel):
    id: UUID
    user_id: UUID
    meditation_id: str | None = None
    duration_seconds: int
    completed: bool
    mood_before: str | None = None
    mood_after: str | None = None
    created_at: datetime | None = None

    model_config = {"from_attributes": True}


# ── Biometrics ───────────────────────────────────────────────────────────────

class BiometricSnapshotCreate(BaseModel):
    session_id: UUID | None = None
    snapshot_type: str = Field(pattern="^(pre_session|post_session|daily)$")
    heart_rate: float | None = Field(default=None, ge=30, le=250)
    hrv: float | None = Field(default=None, ge=0, le=500)
    steps_today: int | None = Field(default=None, ge=0)
    sleep_hours: float | None = Field(default=None, ge=0, le=24)


class BiometricSnapshotOut(BaseModel):
    id: UUID
    user_id: UUID
    session_id: UUID | None = None
    snapshot_type: str
    heart_rate: float | None = None
    hrv: float | None = None
    steps_today: int | None = None
    sleep_hours: float | None = None
    created_at: datetime | None = None

    model_config = {"from_attributes": True}


class SessionContextResponse(BaseModel):
    recommended_duration: int
    recommended_category: str
    intensity: str  # "gentle", "moderate", "deep"
    reasoning: str


# ── Mood entries ─────────────────────────────────────────────────────────────

class MoodEntryCreate(BaseModel):
    primary_emotion: str = Field(max_length=100)
    secondary_emotions: list[str] = Field(default_factory=list, max_length=10)
    intensity: int = Field(ge=1, le=5)
    note: str | None = Field(default=None, max_length=5000)

class MoodEntryOut(BaseModel):
    id: UUID
    user_id: UUID
    primary_emotion: str
    secondary_emotions: list[str] = []
    intensity: int
    note: str | None = None
    ai_insight: str | None = None
    created_at: datetime | None = None

    model_config = {"from_attributes": True}

class InsightUpdate(BaseModel):
    ai_insight: str = Field(max_length=10000)


# ── Garden ───────────────────────────────────────────────────────────────────

class PlantCreate(BaseModel):
    type: str = Field(max_length=50)
    stage: str = Field(default="seed", max_length=50)
    pos_x: float = Field(default=0, ge=0, le=1)
    pos_y: float = Field(default=0, ge=0, le=1)

class PlantUpdate(BaseModel):
    stage: str | None = Field(default=None, max_length=50)
    water_count: int | None = Field(default=None, ge=0)
    health_level: float | None = Field(default=None, ge=0, le=100)
    last_watered_at: datetime | None = None

class PlantOut(BaseModel):
    id: UUID
    user_id: UUID
    type: str
    stage: str
    water_count: int = 0
    health_level: float = 100
    pos_x: float = 0
    pos_y: float = 0
    planted_at: datetime | None = None
    last_watered_at: datetime | None = None

    model_config = {"from_attributes": True}


# ── Partnerships ─────────────────────────────────────────────────────────────

class PartnershipCreate(BaseModel):
    partner_id: UUID
    partner_name: str | None = Field(default=None, max_length=100)
    shared_goals: list[str] = Field(default_factory=list, max_length=20)

class PartnershipUpdate(BaseModel):
    status: str | None = Field(default=None, max_length=50)
    shared_goals: list[str] | None = Field(default=None, max_length=20)

class PartnershipOut(BaseModel):
    id: UUID
    user_id: UUID
    partner_id: UUID
    partner_name: str | None = None
    status: str = "pending"
    shared_goals: list[str] = []
    my_streak: int = 0
    partner_streak: int = 0
    shared_sessions: int = 0
    created_at: datetime | None = None

    model_config = {"from_attributes": True}


# ── Pair messages ────────────────────────────────────────────────────────────

class PairMessageCreate(BaseModel):
    pair_id: UUID
    type: str = Field(default="text", max_length=50)
    content: str | None = Field(default=None, max_length=5000)

class PairMessageOut(BaseModel):
    id: UUID
    pair_id: UUID
    sender_id: UUID
    type: str = "text"
    content: str | None = None
    created_at: datetime | None = None

    model_config = {"from_attributes": True}


# ── AI ───────────────────────────────────────────────────────────────────────

class GenerateMeditationRequest(BaseModel):
    mood: str = Field(max_length=200)
    goal: str = Field(max_length=200)
    duration_minutes: int = Field(ge=3, le=60)
    user_context: str | None = Field(default=None, max_length=1000)

class PersonalMeditationRequest(BaseModel):
    duration_minutes: int = Field(default=10, ge=3, le=60)
    mood_override: str | None = Field(default=None, max_length=200)
    voice: str = Field(default="nova", max_length=50)

class GenerateMeditationResponse(BaseModel):
    title: str
    description: str
    script: str

class PersonalMeditationResponse(BaseModel):
    title: str
    description: str
    script: str
    audio_url: str
    context_summary: str

class MoodAnalysisEntry(BaseModel):
    emotion: str = Field(max_length=100)
    intensity: int = Field(ge=1, le=5)
    note: str | None = Field(default=None, max_length=5000)
    created_at: str

class AnalyzeMoodRequest(BaseModel):
    entries: list[MoodAnalysisEntry] = Field(min_length=1, max_length=365)
    user_goals: list[str] = Field(default_factory=list, max_length=20)

class AnalyzeMoodResponse(BaseModel):
    patterns: list[str] = []
    recommendations: list[str] = []
    summary: str = ""

class TtsRequest(BaseModel):
    text: str = Field(min_length=1, max_length=5000)
    voice_id: str | None = Field(default=None, max_length=100)
    model_id: str | None = Field(default=None, max_length=100)


class TranscriptionResponse(BaseModel):
    text: str
    language: str | None = None
    duration_seconds: float | None = None


class VoiceMoodResponse(BaseModel):
    text: str
    primary_emotion: str
    secondary_emotions: list[str] = []
    intensity: int  # 1-5
    mood_summary: str


# ── Chat (RAG companion) ────────────────────────────────────────────────────

class ChatMessage(BaseModel):
    role: str = Field(pattern="^(user|assistant)$")
    content: str = Field(min_length=1, max_length=4000)

class ChatRequest(BaseModel):
    messages: list[ChatMessage] = Field(min_length=1, max_length=50)
    user_context: str | None = Field(default=None, max_length=2000)
    stream: bool = False

class ChatSource(BaseModel):
    content: str
    source: str
    category: str

class ChatResponse(BaseModel):
    reply: str
    sources: list[ChatSource] = []


# ── Subscriptions ────────────────────────────────────────────────────────────

class SubscriptionOut(BaseModel):
    id: UUID
    user_id: UUID
    plan: str
    status: str
    started_at: datetime | None = None
    expires_at: datetime | None = None
    payment_id: str | None = None
    created_at: datetime | None = None

    model_config = {"from_attributes": True}

class WebhookPayload(BaseModel):
    event: str = Field(max_length=100)
    payment_id: str = Field(max_length=200)
    user_id: UUID
    plan: str = Field(pattern="^(monthly|yearly)$")
    amount: float | None = None


class CreatePaymentRequest(BaseModel):
    plan: Literal["monthly", "yearly"]


class CreatePaymentResponse(BaseModel):
    payment_url: str
    payment_id: str


# ── Notifications / proactive intelligence ───────────────────────────────────

class PushTokenRegister(BaseModel):
    token: str = Field(min_length=1, max_length=512)
    platform: str = Field(default="ios", max_length=20)


class PushTokenRemove(BaseModel):
    token: str = Field(min_length=1, max_length=512)


class ScheduledNotificationOut(BaseModel):
    id: UUID
    user_id: UUID
    title: str
    body: str
    action_type: str = "micro_intervention"
    action_data: dict | None = None
    scheduled_at: datetime
    sent: bool = False
    created_at: datetime | None = None

    model_config = {"from_attributes": True}


class MonthlyDigestResponse(BaseModel):
    letter: str
    stats: dict
