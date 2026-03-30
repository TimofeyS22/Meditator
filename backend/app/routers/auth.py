import secrets
from datetime import datetime, timedelta, timezone

import structlog
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import (
    create_access_token,
    create_refresh_token,
    hash_password,
    rotate_refresh_token,
    verify_password,
)
from app.config import settings
from app.database import get_db
from app.dependencies import get_current_user
from app.models import PasswordResetToken, Profile
from app.rate_limit import limiter
from app.schemas import (
    AuthResponse,
    ForgotPasswordRequest,
    RefreshRequest,
    ResetPasswordRequest,
    SignInRequest,
    SignUpRequest,
    TokenResponse,
    UserOut,
)

logger = structlog.get_logger()
router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
async def signup(request: Request, body: SignUpRequest, db: AsyncSession = Depends(get_db)):
    user = Profile(
        email=body.email,
        display_name=body.display_name or body.email.split("@")[0],
        password_hash=hash_password(body.password),
    )
    db.add(user)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=409, detail="Email already registered")
    await db.refresh(user)

    access = create_access_token(user.id)
    refresh = await create_refresh_token(user.id, db)
    await db.commit()

    logger.info("user_signup", user_id=str(user.id), email=body.email)
    return AuthResponse(user=UserOut.model_validate(user), access_token=access, refresh_token=refresh)


@router.post("/forgot-password", status_code=status.HTTP_200_OK)
@limiter.limit("5/minute")
async def forgot_password(request: Request, body: ForgotPasswordRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Profile).where(Profile.email == body.email))
    user = result.scalar_one_or_none()
    if user:
        await db.execute(
            update(PasswordResetToken)
            .where(
                PasswordResetToken.user_id == user.id,
                PasswordResetToken.used.is_(False),
            )
            .values(used=True)
        )
        raw_token = secrets.token_urlsafe(32)
        expires_at = datetime.now(timezone.utc) + timedelta(hours=1)
        db.add(PasswordResetToken(user_id=user.id, token=raw_token, expires_at=expires_at))
        await db.commit()
        if settings.environment == "dev":
            logger.info(
                "password_reset_token_created",
                user_id=str(user.id),
                email=body.email,
                reset_token=raw_token,
            )
    return {}


@router.post("/reset-password", status_code=status.HTTP_200_OK)
@limiter.limit("10/minute")
async def reset_password(request: Request, body: ResetPasswordRequest, db: AsyncSession = Depends(get_db)):
    now = datetime.now(timezone.utc)
    result = await db.execute(
        select(PasswordResetToken).where(
            PasswordResetToken.token == body.token,
            PasswordResetToken.used.is_(False),
            PasswordResetToken.expires_at > now,
        )
    )
    row = result.scalar_one_or_none()
    if row is None:
        raise HTTPException(status_code=400, detail="Invalid or expired reset token")

    user_result = await db.execute(select(Profile).where(Profile.id == row.user_id))
    user = user_result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=400, detail="Invalid or expired reset token")

    user.password_hash = hash_password(body.new_password)
    row.used = True
    await db.commit()
    logger.info("password_reset_completed", user_id=str(user.id))
    return {}


@router.post("/signin", response_model=AuthResponse)
@limiter.limit("5/minute")
async def signin(request: Request, body: SignInRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Profile).where(Profile.email == body.email))
    user = result.scalar_one_or_none()
    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    access = create_access_token(user.id)
    refresh = await create_refresh_token(user.id, db)
    await db.commit()

    logger.info("user_signin", user_id=str(user.id))
    return AuthResponse(user=UserOut.model_validate(user), access_token=access, refresh_token=refresh)


@router.post("/refresh", response_model=TokenResponse)
@limiter.limit("10/minute")
async def refresh(request: Request, body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    result = await rotate_refresh_token(body.refresh_token, db)
    if result is None:
        raise HTTPException(status_code=401, detail="Invalid or revoked refresh token")
    _, new_access, new_refresh = result
    return TokenResponse(access_token=new_access, refresh_token=new_refresh)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    request: Request,
    body: RefreshRequest,
    db: AsyncSession = Depends(get_db),
    _user: Profile = Depends(get_current_user),
):
    from app.auth import _decode_raw, revoke_family

    payload = _decode_raw(body.refresh_token, "refresh")
    if payload and payload.get("family"):
        await revoke_family(payload["family"], db)


@router.get("/me", response_model=UserOut)
async def me(user: Profile = Depends(get_current_user)):
    return UserOut.model_validate(user)
