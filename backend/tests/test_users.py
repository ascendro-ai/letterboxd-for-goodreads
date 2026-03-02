import uuid

import pytest
from backend.api.model_stubs import Block, User


@pytest.mark.asyncio
async def test_get_my_profile(client, test_user):
    resp = await client.get("/api/v1/me")
    assert resp.status_code == 200
    data = resp.json()
    assert data["username"] == "testuser"
    assert data["books_count"] == 0
    assert data["followers_count"] == 0
    assert data["following_count"] == 0


@pytest.mark.asyncio
async def test_update_profile(client):
    resp = await client.patch(
        "/api/v1/me",
        json={"display_name": "Updated Name", "bio": "Book lover"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["display_name"] == "Updated Name"
    assert data["bio"] == "Book lover"


@pytest.mark.asyncio
async def test_view_other_user_profile(client, other_user):
    resp = await client.get(f"/api/v1/users/{other_user.id}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["username"] == "otheruser"
    assert data["is_following"] is False


@pytest.mark.asyncio
async def test_view_blocked_user_profile(client, db_session, test_user_id, other_user):
    """Viewing a blocked user's profile should return 403."""
    block = Block(blocker_id=str(test_user_id), blocked_id=str(other_user.id))
    db_session.add(block)
    await db_session.commit()

    resp = await client.get(f"/api/v1/users/{other_user.id}")
    assert resp.status_code == 403
    assert resp.json()["detail"]["error"]["code"] == "BLOCKED_USER"


@pytest.mark.asyncio
async def test_search_users(client, db_session):
    user2 = User(
        id=str(uuid.uuid4()),
        username="searchable_user",
        display_name="Searchable",
        is_premium=False,
        is_deleted=False,
    )
    db_session.add(user2)
    await db_session.commit()

    resp = await client.get("/api/v1/users/search?q=searchable")
    assert resp.status_code == 200
    items = resp.json()["items"]
    assert len(items) >= 1
    assert any(u["username"] == "searchable_user" for u in items)


@pytest.mark.asyncio
async def test_view_nonexistent_user(client):
    fake_id = uuid.uuid4()
    resp = await client.get(f"/api/v1/users/{fake_id}")
    assert resp.status_code == 404
