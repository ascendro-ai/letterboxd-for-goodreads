import uuid

import pytest


@pytest.mark.asyncio
async def test_create_shelf(client):
    resp = await client.post(
        "/api/v1/me/shelves",
        json={"name": "Favorites", "description": "My all-time favorites"},
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["name"] == "Favorites"
    assert data["slug"] == "favorites"
    assert data["is_public"] is True


@pytest.mark.asyncio
async def test_create_shelf_limit(client):
    """Free users limited to 20 shelves."""
    for i in range(20):
        resp = await client.post(
            "/api/v1/me/shelves",
            json={"name": f"Shelf {i}"},
        )
        assert resp.status_code == 201

    # 21st should fail
    resp = await client.post(
        "/api/v1/me/shelves",
        json={"name": "One Too Many"},
    )
    assert resp.status_code == 403
    assert resp.json()["detail"]["error"]["code"] == "SHELF_LIMIT_REACHED"


@pytest.mark.asyncio
async def test_create_shelf_premium_bypass(client, db_session, test_user):
    """Premium users can exceed the 20-shelf limit."""
    test_user.is_premium = True
    await db_session.commit()

    for i in range(25):
        resp = await client.post(
            "/api/v1/me/shelves",
            json={"name": f"Premium Shelf {i}"},
        )
        assert resp.status_code == 201


@pytest.mark.asyncio
async def test_list_shelves(client):
    await client.post("/api/v1/me/shelves", json={"name": "Shelf A"})
    await client.post("/api/v1/me/shelves", json={"name": "Shelf B"})

    resp = await client.get("/api/v1/me/shelves")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 2


@pytest.mark.asyncio
async def test_update_shelf(client):
    create_resp = await client.post("/api/v1/me/shelves", json={"name": "Old Name"})
    shelf_id = create_resp.json()["id"]

    resp = await client.patch(
        f"/api/v1/me/shelves/{shelf_id}",
        json={"name": "New Name", "is_public": False},
    )
    assert resp.status_code == 200
    assert resp.json()["name"] == "New Name"
    assert resp.json()["is_public"] is False


@pytest.mark.asyncio
async def test_delete_shelf(client):
    create_resp = await client.post("/api/v1/me/shelves", json={"name": "Delete Me"})
    shelf_id = create_resp.json()["id"]

    resp = await client.delete(f"/api/v1/me/shelves/{shelf_id}")
    assert resp.status_code == 200

    list_resp = await client.get("/api/v1/me/shelves")
    assert len(list_resp.json()) == 0


@pytest.mark.asyncio
async def test_add_book_to_shelf(client, test_work):
    # Log a book first
    book_resp = await client.post(
        "/api/v1/me/books",
        json={"work_id": str(test_work.id), "status": "want_to_read"},
    )
    user_book_id = book_resp.json()["id"]

    # Create shelf
    shelf_resp = await client.post("/api/v1/me/shelves", json={"name": "My Shelf"})
    shelf_id = shelf_resp.json()["id"]

    # Add book
    resp = await client.post(
        f"/api/v1/me/shelves/{shelf_id}/books",
        json={"user_book_id": user_book_id},
    )
    assert resp.status_code == 201


@pytest.mark.asyncio
async def test_delete_shelf_not_found(client):
    fake_id = uuid.uuid4()
    resp = await client.delete(f"/api/v1/me/shelves/{fake_id}")
    assert resp.status_code == 404
