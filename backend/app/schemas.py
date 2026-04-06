from datetime import datetime
from pydantic import BaseModel, EmailStr, Field


# ── Auth ────────────────────────────────────────────────────────────────────

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    display_name: str = Field(default="", max_length=100)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshRequest(BaseModel):
    refresh_token: str


# ── Profile ─────────────────────────────────────────────────────────────────

class ProfileResponse(BaseModel):
    id: str
    email: str
    display_name: str
    is_premium: bool
    total_sessions: int
    current_streak: int
    longest_streak: int
    total_minutes: int
    preferred_duration: int
    notification_enabled: bool
    notification_hour: int
    companion_tone: str
    emotional_trend: str
    created_at: datetime


class ProfileUpdateRequest(BaseModel):
    display_name: str | None = None
    preferred_duration: int | None = Field(default=None, ge=30, le=3600)
    notification_enabled: bool | None = None
    notification_hour: int | None = Field(default=None, ge=0, le=23)


# ── Mood ────────────────────────────────────────────────────────────────────

class MoodCreateRequest(BaseModel):
    emotion: str = Field(pattern=r"^(anxiety|fatigue|overload|emptiness|calm)$")
    intensity: int = Field(ge=1, le=5, default=3)
    note: str | None = Field(default=None, max_length=2000)
    context: str | None = Field(
        default=None, pattern=r"^(checkin|reality_break|post_session)$",
    )


class MoodResponse(BaseModel):
    id: str
    emotion: str
    intensity: int
    note: str | None
    context: str | None
    ai_insight: str | None
    created_at: datetime


class MoodHistoryResponse(BaseModel):
    entries: list[MoodResponse]
    total: int


# ── Sessions ────────────────────────────────────────────────────────────────

class SessionCreateRequest(BaseModel):
    session_type: str
    duration_seconds: int = Field(ge=10, le=3600)
    completed: bool = False
    mood_before: str | None = None
    mood_after: str | None = None
    audio_track: str | None = None


class SessionResponse(BaseModel):
    id: str
    session_type: str
    duration_seconds: int
    completed: bool
    mood_before: str | None
    mood_after: str | None
    created_at: datetime


class StatsResponse(BaseModel):
    total_sessions: int
    current_streak: int
    longest_streak: int
    total_minutes: int
    last_session_date: str | None


# ── Companion ───────────────────────────────────────────────────────────────

class CompanionRequest(BaseModel):
    current_mood: str = Field(pattern=r"^(anxiety|fatigue|overload|emptiness|calm)$")
    hour: int = Field(ge=0, le=23)
    intensity: int = Field(ge=1, le=5, default=3)
    seconds_since_last_checkin: int | None = Field(default=None, ge=0)


class ImmediateActionResponse(BaseModel):
    label: str
    short_prompt: str
    session_type: str
    duration_seconds: int
    color_hex: str


class UniverseResponse(BaseModel):
    brightness: float
    star_density: float
    nebula_intensity: float
    particle_speed: float
    dominant_color_hex: str
    accent_color_hex: str


class CompanionResponse(BaseModel):
    response_mode: str
    presence: str
    insight: str | None = None
    universe_mood: str
    action: ImmediateActionResponse | None = None
    universe: UniverseResponse
    tone: str
    patterns_summary: str | None = None
    orb_breath_speed: float
    recognition: str | None = None


# ── AI Generation ───────────────────────────────────────────────────────────

class GenerateMeditationRequest(BaseModel):
    mood: str
    goal: str
    duration_minutes: int = Field(ge=1, le=30)


class GenerateMeditationResponse(BaseModel):
    title: str
    description: str
    script: str


class TTSRequest(BaseModel):
    text: str = Field(max_length=5000)
    voice_id: str | None = None
