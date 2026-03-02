"""Tests for reading statistics (Plan 25-B)."""

import pytest


@pytest.mark.asyncio
class TestReadingStats:
    """Reading stats endpoints."""

    async def test_get_own_stats(self, client):
        """Users can fetch their own stats."""
        resp = await client.get("/api/v1/me/stats")
        assert resp.status_code == 200
        data = resp.json()
        assert "total_books" in data
        assert "total_read" in data
        assert "total_reading" in data
        assert "total_want_to_read" in data
        assert "current_year_stats" in data
        assert "yearly_stats" in data

    async def test_get_other_user_stats(self, client, other_user_id):
        """Users can fetch another user's stats."""
        resp = await client.get(f"/api/v1/users/{other_user_id}/stats")
        assert resp.status_code == 200

    async def test_hidden_stats_returns_404(self, client, hidden_stats_user):
        """If a user hides stats, other users get 404."""
        resp = await client.get(f"/api/v1/users/{hidden_stats_user.id}/stats")
        assert resp.status_code == 404

    async def test_stats_with_books(self, client, logged_books):
        """Stats reflect logged books."""
        resp = await client.get("/api/v1/me/stats")
        assert resp.status_code == 200
        data = resp.json()
        assert data["total_books"] >= 1
        assert data["total_read"] >= 1

    async def test_stats_schema_shape(self, client):
        """Stats response includes all expected fields."""
        resp = await client.get("/api/v1/me/stats")
        assert resp.status_code == 200
        data = resp.json()
        current = data["current_year_stats"]
        assert "year" in current
        assert "books_read" in current
