import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_list_meditations(client: AsyncClient):
    resp = await client.get("/meditations")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)


@pytest.mark.asyncio
async def test_list_meditations_with_limit(client: AsyncClient):
    resp = await client.get("/meditations", params={"limit": 5})
    assert resp.status_code == 200
    assert len(resp.json()) <= 5


@pytest.mark.asyncio
async def test_list_meditations_limit_too_high(client: AsyncClient):
    resp = await client.get("/meditations", params={"limit": 999})
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_create_session(auth_client: AsyncClient):
    resp = await auth_client.post("/sessions", json={
        "duration_seconds": 300,
        "completed": True,
    })
    assert resp.status_code == 201
    data = resp.json()
    assert data["duration_seconds"] == 300
    assert data["completed"] is True


@pytest.mark.asyncio
async def test_create_session_invalid_duration(auth_client: AsyncClient):
    resp = await auth_client.post("/sessions", json={
        "duration_seconds": -1,
        "completed": True,
    })
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_streak_increments(auth_client: AsyncClient):
    await auth_client.post("/sessions", json={
        "duration_seconds": 600,
        "completed": True,
    })
    profile = await auth_client.get("/profiles/me")
    data = profile.json()
    assert data["current_streak"] >= 1
    assert data["total_sessions"] >= 1
    assert data["total_minutes"] >= 10


@pytest.mark.asyncio
async def test_list_sessions(auth_client: AsyncClient):
    await auth_client.post("/sessions", json={
        "duration_seconds": 120,
        "completed": False,
    })
    resp = await auth_client.get("/sessions")
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


@pytest.mark.asyncio
async def test_create_mood_entry(auth_client: AsyncClient):
    resp = await auth_client.post("/mood-entries", json={
        "primary_emotion": "joy",
        "secondary_emotions": ["gratitude"],
        "intensity": 4,
        "note": "Great day",
    })
    assert resp.status_code == 201
    data = resp.json()
    assert data["primary_emotion"] == "joy"
    assert data["intensity"] == 4


@pytest.mark.asyncio
async def test_mood_entry_intensity_bounds(auth_client: AsyncClient):
    resp = await auth_client.post("/mood-entries", json={
        "primary_emotion": "anger",
        "intensity": 0,
    })
    assert resp.status_code == 422

    resp2 = await auth_client.post("/mood-entries", json={
        "primary_emotion": "anger",
        "intensity": 6,
    })
    assert resp2.status_code == 422


@pytest.mark.asyncio
async def test_list_mood_entries(auth_client: AsyncClient):
    await auth_client.post("/mood-entries", json={
        "primary_emotion": "calm",
        "intensity": 3,
    })
    resp = await auth_client.get("/mood-entries")
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


@pytest.mark.asyncio
async def test_update_mood_insight(auth_client: AsyncClient):
    create_resp = await auth_client.post("/mood-entries", json={
        "primary_emotion": "sadness",
        "intensity": 2,
    })
    entry_id = create_resp.json()["id"]
    resp = await auth_client.patch(f"/mood-entries/{entry_id}/insight", json={
        "ai_insight": "Pattern detected: low energy in evenings",
    })
    assert resp.status_code == 200
    assert resp.json()["ai_insight"] is not None


@pytest.mark.asyncio
async def test_garden_plant_lifecycle(auth_client: AsyncClient):
    create = await auth_client.post("/garden-plants", json={
        "type": "tree",
        "stage": "seed",
        "pos_x": 0.5,
        "pos_y": 0.3,
    })
    assert create.status_code == 201
    plant_id = create.json()["id"]

    update = await auth_client.patch(f"/garden-plants/{plant_id}", json={
        "stage": "sprout",
        "water_count": 1,
    })
    assert update.status_code == 200
    assert update.json()["stage"] == "sprout"

    plants = await auth_client.get("/garden-plants")
    assert plants.status_code == 200
    assert len(plants.json()) >= 1


@pytest.mark.asyncio
async def test_profile_update(auth_client: AsyncClient):
    resp = await auth_client.put("/profiles/me", json={
        "display_name": "Updated Name",
        "preferred_time_hour": 8,
    })
    assert resp.status_code == 200
    assert resp.json()["display_name"] == "Updated Name"
    assert resp.json()["preferred_time_hour"] == 8


@pytest.mark.asyncio
async def test_profile_time_hour_bounds(auth_client: AsyncClient):
    resp = await auth_client.put("/profiles/me", json={
        "preferred_time_hour": 25,
    })
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_health_endpoint(client: AsyncClient):
    resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_unauthenticated_crud(client: AsyncClient):
    assert (await client.get("/sessions")).status_code in (401, 403)
    assert (await client.get("/mood-entries")).status_code in (401, 403)
    assert (await client.get("/garden-plants")).status_code in (401, 403)
    assert (await client.get("/profiles/me")).status_code in (401, 403)
