from pydantic import model_validator
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    environment: str = "dev"
    database_url: str = "postgresql+asyncpg://meditator:meditator_secret@localhost:5432/meditator"
    jwt_secret: str = "change-me"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 30
    openai_api_key: str = ""
    openai_base_url: str = "https://api.proxyapi.ru/openai/v1"
    elevenlabs_api_key: str = ""
    openai_model: str = "gpt-4o"
    openai_embedding_model: str = "text-embedding-3-small"
    rag_top_k: int = 5
    sentry_dsn: str = ""
    webhook_secret: str = ""
    yookassa_shop_id: str = ""
    yookassa_secret_key: str = ""
    admin_secret: str = ""
    fcm_server_key: str = ""
    allowed_origins: list[str] = ["http://localhost:3000", "http://localhost:8080"]

    model_config = {"env_file": ".env", "extra": "ignore"}

    @model_validator(mode="after")
    def _validate_production(self):
        if self.environment != "dev" and (
            len(self.jwt_secret) < 32 or self.jwt_secret == "change-me"
        ):
            raise ValueError(
                "JWT_SECRET must be at least 32 characters in non-dev environments"
            )
        return self


settings = Settings()
