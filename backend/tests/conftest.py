from collections.abc import AsyncGenerator

import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import pool, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.database import get_db
from app.main import app
from app.models import Base
from app.rate_limit import limiter

TEST_DATABASE_URL = "postgresql+asyncpg://meditator:meditator_secret@localhost:5433/meditator_test"

engine = create_async_engine(TEST_DATABASE_URL, echo=False, poolclass=pool.NullPool)
TestSession = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


@pytest_asyncio.fixture(autouse=True)
async def setup_db():
    async with engine.begin() as conn:
        await conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


async def override_get_db() -> AsyncGenerator[AsyncSession, None]:
    async with TestSession() as session:
        yield session


app.dependency_overrides[get_db] = override_get_db
limiter.enabled = False


@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest_asyncio.fixture
async def auth_client(client: AsyncClient) -> AsyncClient:
    resp = await client.post("/auth/signup", json={
        "email": "testuser@example.com",
        "password": "testpass123",
        "display_name": "Test User",
    })
    token = resp.json()["access_token"]
    client.headers["Authorization"] = f"Bearer {token}"
    return client
