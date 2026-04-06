import time
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.database import engine, Base
from app.config import settings, _DEFAULT_SECRET, logger
from app.routes import (
    auth_router, profile_router, sessions_router,
    mood_router, companion_router, meditations_router, tts_router,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    if settings.jwt_secret == _DEFAULT_SECRET:
        logger.warning(
            "JWT_SECRET is using the default value. "
            "Set a strong secret via environment variable for production."
        )

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("Database tables verified")
    yield
    await engine.dispose()


app = FastAPI(title="Aura API", version="2.1.0", lifespan=lifespan)

# ── CORS (no wildcard + credentials) ─────────────────────────────────────────

origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=len(origins) > 0 and "*" not in origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Simple in-memory rate limiter ─────────────────────────────────────────────

_rate_buckets: dict[str, list[float]] = {}

@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    if request.url.path.startswith("/api/auth/"):
        client_ip = request.client.host if request.client else "unknown"
        now = time.time()
        window = 60.0
        bucket = _rate_buckets.setdefault(client_ip, [])
        bucket[:] = [t for t in bucket if now - t < window]

        if len(bucket) >= settings.rate_limit_per_minute:
            logger.warning("Rate limit exceeded for %s on %s", client_ip, request.url.path)
            return JSONResponse(
                status_code=429,
                content={"detail": "Too many requests. Try again later."},
            )
        bucket.append(now)

    return await call_next(request)

# ── Request logging ───────────────────────────────────────────────────────────

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    elapsed = (time.time() - start) * 1000
    logger.info(
        "%s %s %d %.0fms",
        request.method, request.url.path, response.status_code, elapsed,
    )
    return response

# ── Routers ───────────────────────────────────────────────────────────────────

app.include_router(auth_router, prefix="/api/auth", tags=["auth"])
app.include_router(profile_router, prefix="/api/profile", tags=["profile"])
app.include_router(sessions_router, prefix="/api/sessions", tags=["sessions"])
app.include_router(mood_router, prefix="/api/mood", tags=["mood"])
app.include_router(companion_router, prefix="/api/companion", tags=["companion"])
app.include_router(meditations_router, prefix="/api/meditations", tags=["meditations"])
app.include_router(tts_router, prefix="/api/tts", tags=["tts"])


@app.get("/health")
async def health():
    from sqlalchemy import text
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        db_ok = True
    except Exception:
        db_ok = False

    status = "ok" if db_ok else "degraded"
    return {"status": status, "version": "2.1.0", "db": db_ok}
