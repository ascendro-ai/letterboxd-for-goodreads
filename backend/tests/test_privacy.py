"""Tests for per-book privacy (Plan 25-A)."""

import pytest


@pytest.mark.asyncio
class TestBookPrivacy:
    """Per-book privacy: private books hidden from other users, no activity."""

    async def test_log_private_book(self, client, auth_headers, work_id):
        """Private books are created with is_private=True."""
        resp = await client.post(
            "/api/v1/me/books",
            json={"work_id": str(work_id), "status": "reading", "is_private": True},
            headers=auth_headers,
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["is_private"] is True

    async def test_private_book_hidden_from_others(
        self, client, other_client, user_id, work_id
    ):
        """Other users cannot see private books in your library."""
        # Log a private book as test_user
        await client.post(
            "/api/v1/me/books",
            json={"work_id": str(work_id), "status": "read", "is_private": True},
        )

        # Other user fetches test_user's library
        resp = await other_client.get(f"/api/v1/users/{user_id}/books")
        assert resp.status_code == 200
        books = resp.json()["items"]
        private_books = [b for b in books if b.get("is_private")]
        assert len(private_books) == 0

    async def test_private_book_visible_to_owner(self, client, work_id):
        """Owner can see their own private books."""
        await client.post(
            "/api/v1/me/books",
            json={"work_id": str(work_id), "status": "reading", "is_private": True},
        )

        resp = await client.get("/api/v1/me/books")
        assert resp.status_code == 200
        books = resp.json()["items"]
        assert any(b.get("is_private") for b in books)

    async def test_private_book_no_activity(self, client, other_client, work_id):
        """Private books don't create feed entries."""
        await client.post(
            "/api/v1/me/books",
            json={"work_id": str(work_id), "status": "read", "is_private": True},
        )

        resp = await other_client.get("/api/v1/feed")
        assert resp.status_code == 200
        items = resp.json()["items"]
        for item in items:
            assert item.get("book", {}).get("id") != str(work_id)

    async def test_update_book_to_private(self, client, work_id):
        """Updating a book to private works."""
        resp = await client.post(
            "/api/v1/me/books",
            json={"work_id": str(work_id), "status": "reading"},
        )
        user_book_id = resp.json()["id"]

        resp = await client.patch(
            f"/api/v1/me/books/{user_book_id}",
            json={"is_private": True},
        )
        assert resp.status_code == 200
        assert resp.json()["is_private"] is True
