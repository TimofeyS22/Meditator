import logging
import sys

from pydantic_settings import BaseSettings

_DEFAULT_SECRET = "change-me-in-production-use-long-random-string"


class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://meditator:meditator@db:5432/meditator"

    jwt_secret: str = _DEFAULT_SECRET
    jwt_algorithm: str = "HS256"
    jwt_access_minutes: int = 30
    jwt_refresh_days: int = 30

    openai_api_key: str = ""
    openai_model: str = "gpt-4o"

    ai_base_url: str = "https://api.proxyapi.ru/openai/v1"
    ai_api_key: str = ""
    ai_model: str = "gpt-4o"

    elevenlabs_api_key: str = ""
    elevenlabs_voice_id: str = "pNInz6obpgDQGcFmaJgB"
    elevenlabs_model_id: str = "eleven_multilingual_v2"

    cors_origins: str = "http://localhost:3000"

    rate_limit_per_minute: int = 30

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()


# ── Logging ───────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("aura")
