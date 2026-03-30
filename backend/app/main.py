import uuid as uuid_mod
from contextlib import asynccontextmanager
from pathlib import Path

import structlog
from fastapi import Depends, FastAPI, Request
from fastapi.staticfiles import StaticFiles
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from sqlalchemy import text

from app.config import settings
from app.database import async_session, engine, get_db
from app.logging_config import setup_logging
from app.models import Base
from app.routers import (
    admin,
    ai,
    auth,
    biometrics,
    chat,
    community,
    courses,
    garden,
    live_session,
    meditations,
    mood_entries,
    notifications,
    pair_messages,
    partnerships,
    profiles,
    sessions,
    subscriptions,
)
from app.rate_limit import limiter
from app.seed import seed_meditations

setup_logging()
logger = structlog.get_logger()

if settings.sentry_dsn:
    import sentry_sdk

    sentry_sdk.init(
        dsn=settings.sentry_dsn,
        environment=settings.environment,
        traces_sample_rate=0.1 if settings.environment == "prod" else 1.0,
        profiles_sample_rate=0.1 if settings.environment == "prod" else 1.0,
    )


@asynccontextmanager
async def lifespan(app: FastAPI):
    if settings.environment == "dev":
        async with engine.begin() as conn:
            await conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
            await conn.run_sync(Base.metadata.create_all)
    async with async_session() as db:
        count = await seed_meditations(db)
        if count:
            logger.info("seeded_meditations", count=count)
    yield
    await engine.dispose()


app = FastAPI(
    title="Meditator API",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.environment == "dev" else None,
    redoc_url=None,
)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def request_id_middleware(request: Request, call_next):
    request_id = request.headers.get("X-Request-ID", str(uuid_mod.uuid4()))
    structlog.contextvars.clear_contextvars()
    structlog.contextvars.bind_contextvars(request_id=request_id)
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    return response


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    logger.exception("unhandled_error", path=str(request.url.path), method=request.method)
    return JSONResponse(status_code=500, content={"detail": "Internal server error"})


app.include_router(auth.router)
app.include_router(profiles.router)
app.include_router(meditations.router)
app.include_router(sessions.router)
app.include_router(biometrics.router)
app.include_router(mood_entries.router)
app.include_router(garden.router)
app.include_router(partnerships.router)
app.include_router(pair_messages.router)
app.include_router(ai.router)
app.include_router(chat.router)
app.include_router(subscriptions.router)
app.include_router(admin.router)
app.include_router(notifications.router)
app.include_router(live_session.router)
app.include_router(courses.router)
app.include_router(community.router)


_audio_dir = Path(__file__).resolve().parent.parent / "assets" / "audio"
if _audio_dir.is_dir():
    app.mount("/audio", StaticFiles(directory=str(_audio_dir)), name="audio")


@app.get("/health")
async def health(db: AsyncSession = Depends(get_db)):
    try:
        await db.execute(text("SELECT 1"))
        return {"status": "ok", "db": "connected"}
    except Exception:
        return JSONResponse(status_code=503, content={"status": "error", "db": "disconnected"})
