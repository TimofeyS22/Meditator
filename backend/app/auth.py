from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4

import bcrypt
import structlog
from jose import JWTError, jwt
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings

logger = structlog.get_logger()


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode(), hashed.encode())


def create_access_token(user_id: UUID) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_expire_minutes)
    return jwt.encode(
        {"sub": str(user_id), "exp": expire, "type": "access"},
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )


def _encode_refresh(user_id: UUID, jti: str, family: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expire_days)
    return jwt.encode(
        {"sub": str(user_id), "exp": expire, "type": "refresh", "jti": jti, "family": family},
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )


async def create_refresh_token(user_id: UUID, db: AsyncSession, family: str | None = None) -> str:
    from app.models import RefreshToken

    jti = str(uuid4())
    family = family or str(uuid4())
    expires_at = datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expire_days)

    token_row = RefreshToken(user_id=user_id, jti=jti, family=family, expires_at=expires_at)
    db.add(token_row)
    await db.flush()

    return _encode_refresh(user_id, jti, family)


async def rotate_refresh_token(old_token: str, db: AsyncSession) -> tuple[UUID, str, str] | None:
    """Validate and rotate a refresh token. Returns (user_id, new_access, new_refresh) or None."""
    from app.models import RefreshToken

    payload = _decode_raw(old_token, expected_type="refresh")
    if payload is None:
        return None

    user_id = UUID(payload["sub"])
    jti = payload.get("jti")
    family = payload.get("family")

    if not jti or not family:
        return None

    row = await db.execute(
        select(RefreshToken).where(RefreshToken.jti == jti)
    )
    token_row = row.scalar_one_or_none()

    if token_row is None:
        return None

    if token_row.revoked:
        logger.warning("refresh_token_reuse_detected", family=family, user_id=str(user_id))
        await db.execute(
            update(RefreshToken).where(RefreshToken.family == family).values(revoked=True)
        )
        await db.commit()
        return None

    token_row.revoked = True
    await db.flush()

    new_access = create_access_token(user_id)
    new_refresh = await create_refresh_token(user_id, db, family=family)
    await db.commit()

    return user_id, new_access, new_refresh


async def revoke_family(family: str, db: AsyncSession) -> None:
    from app.models import RefreshToken
    await db.execute(
        update(RefreshToken).where(RefreshToken.family == family).values(revoked=True)
    )
    await db.commit()


def decode_token(token: str, expected_type: str = "access") -> UUID | None:
    payload = _decode_raw(token, expected_type)
    if payload is None:
        return None
    sub = payload.get("sub")
    return UUID(sub) if sub else None


def _decode_raw(token: str, expected_type: str) -> dict | None:
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
        if payload.get("type") != expected_type:
            return None
        return payload
    except (JWTError, ValueError):
        return None
