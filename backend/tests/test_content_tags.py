"""Tests for community content tags (Plan 25-C)."""

import pytest


@pytest.mark.asyncio
class TestContentTags:
    """Content warning and mood tag voting endpoints."""

    async def test_get_available_tags(self, client):
        """GET /books/tags/available returns grouped tag lists."""
        resp = await client.get("/api/v1/books/tags/available")
        assert resp.status_code == 200
        data = resp.json()
        assert "content_warnings" in data
        assert "moods" in data
        assert "graphic_violence" in data["content_warnings"]
        assert "slow_burn" in data["moods"]

    async def test_vote_for_tag(self, client, work_id):
        """POST vote creates a tag with vote_count=1."""
        resp = await client.post(
            f"/api/v1/books/{work_id}/tags/vote",
            json={"tag_name": "graphic_violence"},
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["tag_name"] == "graphic_violence"
        assert data["tag_type"] == "content_warning"
        assert data["vote_count"] == 1
        assert data["is_confirmed"] is False

    async def test_duplicate_vote_rejected(self, client, work_id):
        """Voting twice for the same tag returns 409."""
        await client.post(
            f"/api/v1/books/{work_id}/tags/vote",
            json={"tag_name": "slow_burn"},
        )
        resp = await client.post(
            f"/api/v1/books/{work_id}/tags/vote",
            json={"tag_name": "slow_burn"},
        )
        assert resp.status_code == 409

    async def test_invalid_tag_rejected(self, client, work_id):
        """Invalid tag names return 422."""
        resp = await client.post(
            f"/api/v1/books/{work_id}/tags/vote",
            json={"tag_name": "not_a_real_tag"},
        )
        assert resp.status_code == 422

    async def test_remove_vote(self, client, work_id):
        """DELETE removes the vote and decrements count."""
        await client.post(
            f"/api/v1/books/{work_id}/tags/vote",
            json={"tag_name": "dark"},
        )
        resp = await client.delete(
            f"/api/v1/books/{work_id}/tags/dark/vote",
        )
        assert resp.status_code == 204

    async def test_get_work_tags(self, client, work_id):
        """GET returns all tags for a work."""
        await client.post(
            f"/api/v1/books/{work_id}/tags/vote",
            json={"tag_name": "emotional"},
        )

        resp = await client.get(f"/api/v1/books/{work_id}/tags")
        assert resp.status_code == 200
        tags = resp.json()
        assert len(tags) >= 1
        assert any(t["tag_name"] == "emotional" for t in tags)

    async def test_tag_confirmed_at_threshold(
        self, client_as, user_2, user_3, test_user, work_id
    ):
        """Tag becomes confirmed when vote_count reaches threshold (3)."""
        # Three different users vote for the same tag
        for user in [test_user, user_2, user_3]:
            c = await client_as(user)
            resp = await c.post(
                f"/api/v1/books/{work_id}/tags/vote",
                json={"tag_name": "tense"},
            )

        # Last vote should show confirmed
        assert resp.status_code == 201
        assert resp.json()["is_confirmed"] is True
        assert resp.json()["vote_count"] == 3
