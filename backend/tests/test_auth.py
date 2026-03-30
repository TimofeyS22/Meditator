import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.models import PasswordResetToken
from tests.conftest import TestSession


@pytest.mark.asyncio
async def test_signup_success(client: AsyncClient):
    resp = await client.post("/auth/signup", json={
        "email": "new@example.com",
        "password": "strongpass123",
    })
    assert resp.status_code == 201
    data = resp.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["user"]["email"] == "new@example.com"
    assert data["user"]["display_name"] == "new"


@pytest.mark.asyncio
async def test_signup_duplicate_email(client: AsyncClient):
    await client.post("/auth/signup", json={
        "email": "dupe@example.com",
        "password": "strongpass123",
    })
    resp = await client.post("/auth/signup", json={
        "email": "dupe@example.com",
        "password": "otherpass123",
    })
    assert resp.status_code == 409


@pytest.mark.asyncio
async def test_signup_invalid_email(client: AsyncClient):
    resp = await client.post("/auth/signup", json={
        "email": "not-an-email",
        "password": "strongpass123",
    })
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_signup_short_password(client: AsyncClient):
    resp = await client.post("/auth/signup", json={
        "email": "short@example.com",
        "password": "123",
    })
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_signin_success(client: AsyncClient):
    await client.post("/auth/signup", json={
        "email": "signin@example.com",
        "password": "testpass123",
    })
    resp = await client.post("/auth/signin", json={
        "email": "signin@example.com",
        "password": "testpass123",
    })
    assert resp.status_code == 200
    assert "access_token" in resp.json()


@pytest.mark.asyncio
async def test_signin_wrong_password(client: AsyncClient):
    await client.post("/auth/signup", json={
        "email": "wrong@example.com",
        "password": "testpass123",
    })
    resp = await client.post("/auth/signin", json={
        "email": "wrong@example.com",
        "password": "badpassword",
    })
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_signin_nonexistent_email(client: AsyncClient):
    resp = await client.post("/auth/signin", json={
        "email": "nobody@example.com",
        "password": "whatever",
    })
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_refresh_token(client: AsyncClient):
    resp = await client.post("/auth/signup", json={
        "email": "refresh@example.com",
        "password": "testpass123",
    })
    refresh_token = resp.json()["refresh_token"]
    resp2 = await client.post("/auth/refresh", json={
        "refresh_token": refresh_token,
    })
    assert resp2.status_code == 200
    assert "access_token" in resp2.json()


@pytest.mark.asyncio
async def test_refresh_invalid_token(client: AsyncClient):
    resp = await client.post("/auth/refresh", json={
        "refresh_token": "invalid.token.here",
    })
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_me_authenticated(auth_client: AsyncClient):
    resp = await auth_client.get("/auth/me")
    assert resp.status_code == 200
    assert resp.json()["email"] == "testuser@example.com"


@pytest.mark.asyncio
async def test_me_unauthenticated(client: AsyncClient):
    resp = await client.get("/auth/me")
    assert resp.status_code in (401, 403)


@pytest.mark.asyncio
async def test_forgot_password_unknown_email_ok(client: AsyncClient):
    resp = await client.post("/auth/forgot-password", json={"email": "missing@example.com"})
    assert resp.status_code == 200
    assert resp.json() == {}


@pytest.mark.asyncio
async def test_forgot_and_reset_password_flow(client: AsyncClient):
    await client.post(
        "/auth/signup",
        json={"email": "pwreset@example.com", "password": "original12"},
    )
    resp_forgot = await client.post(
        "/auth/forgot-password",
        json={"email": "pwreset@example.com"},
    )
    assert resp_forgot.status_code == 200

    async with TestSession() as session:
        r = await session.execute(
            select(PasswordResetToken).where(PasswordResetToken.used.is_(False))
        )
        row = r.scalar_one()
        token_val = row.token

    resp_reset = await client.post(
        "/auth/reset-password",
        json={"token": token_val, "new_password": "newsecret12"},
    )
    assert resp_reset.status_code == 200

    bad = await client.post(
        "/auth/signin",
        json={"email": "pwreset@example.com", "password": "original12"},
    )
    assert bad.status_code == 401

    ok = await client.post(
        "/auth/signin",
        json={"email": "pwreset@example.com", "password": "newsecret12"},
    )
    assert ok.status_code == 200


@pytest.mark.asyncio
async def test_reset_password_invalid_token(client: AsyncClient):
    resp = await client.post(
        "/auth/reset-password",
        json={"token": "not-a-valid-token", "new_password": "newsecret12"},
    )
    assert resp.status_code == 400
