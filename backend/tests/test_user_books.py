import uuid

import pytest


@pytest.mark.asyncio
async def test_log_book_success(client, test_work):
    resp = await client.post(
        "/api/v1/me/books",
        json={
            "work_id": str(test_work.id),
            "status": "read",
            "rating": 4.5,
            "review_text": "Great book!",
        },
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["status"] == "read"
    assert float(data["rating"]) == 4.5
    assert data["review_text"] == "Great book!"


@pytest.mark.asyncio
async def test_log_book_duplicate(client, test_work):
    await client.post(
        "/api/v1/me/books",
        json={
            "work_id": str(test_work.id),
            "status": "read",
            "rating": 4.0,
            "review_text": "Good.",
        },
    )
    resp = await client.post(
        "/api/v1/me/books",
        json={
            "work_id": str(test_work.id),
            "status": "read",
            "rating": 3.0,
            "review_text": "Changed my mind.",
        },
    )
    assert resp.status_code == 409
    data = resp.json()
    assert data["detail"]["error"]["code"] == "ALREADY_LOGGED"


@pytest.mark.asyncio
async def test_log_book_review_required(client, test_work):
    """Rating without review text should fail for non-imported books."""
    resp = await client.post(
        "/api/v1/me/books",
        json={
            "work_id": str(test_work.id),
            "status": "read",
            "rating": 4.0,
        },
    )
    assert resp.status_code == 422
    data = resp.json()
    assert data["detail"]["error"]["code"] == "REVIEW_REQUIRED"


@pytest.mark.asyncio
async def test_log_book_invalid_rating(client, test_work):
    """Rating not in 0.5 increments should fail validation."""
    resp = await client.post(
        "/api/v1/me/books",
        json={
            "work_id": str(test_work.id),
            "status": "read",
            "rating": 4.3,
            "review_text": "Some review",
        },
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_log_book_no_rating_ok(client, test_work):
    """Logging without a rating (just status) should succeed."""
    resp = await client.post(
        "/api/v1/me/books",
        json={
            "work_id": str(test_work.id),
            "status": "want_to_read",
        },
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["rating"] is None


@pytest.mark.asyncio
async def test_update_book(client, test_work):
    create_resp = await client.post(
        "/api/v1/me/books",
        json={
            "work_id": str(test_work.id),
            "status": "reading",
        },
    )
    user_book_id = create_resp.json()["id"]

    resp = await client.patch(
        f"/api/v1/me/books/{user_book_id}",
        json={"status": "read", "rating": 5.0, "review_text": "Masterpiece!"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "read"
    assert float(data["rating"]) == 5.0


@pytest.mark.asyncio
async def test_delete_book(client, test_work):
    create_resp = await client.post(
        "/api/v1/me/books",
        json={
            "work_id": str(test_work.id),
            "status": "want_to_read",
        },
    )
    user_book_id = create_resp.json()["id"]

    resp = await client.delete(f"/api/v1/me/books/{user_book_id}")
    assert resp.status_code == 200

    # Verify it's gone
    list_resp = await client.get("/api/v1/me/books")
    assert list_resp.status_code == 200
    assert list_resp.json()["items"] == []


@pytest.mark.asyncio
async def test_list_my_books_with_status_filter(client, db_session, test_user_id):
    """Create books with different statuses and filter."""
    from backend.api.model_stubs import Work

    works = []
    for i, status in enumerate(["read", "reading", "want_to_read"]):
        w = Work(id=str(uuid.uuid4()), title=f"Book {i}", ratings_count=0)
        db_session.add(w)
        await db_session.flush()
        works.append(w)

        payload = {"work_id": str(w.id), "status": status}
        if status == "read":
            payload["rating"] = 4.0
            payload["review_text"] = "Review"
        await client.post("/api/v1/me/books", json=payload)

    # Filter by read
    resp = await client.get("/api/v1/me/books?status=read")
    assert resp.status_code == 200
    items = resp.json()["items"]
    assert len(items) == 1
    assert items[0]["status"] == "read"

    # No filter: all three
    resp = await client.get("/api/v1/me/books")
    assert resp.status_code == 200
    assert len(resp.json()["items"]) == 3
