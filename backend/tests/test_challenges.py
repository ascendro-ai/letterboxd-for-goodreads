"""Tests for reading challenge endpoints and service."""

import uuid
from datetime import datetime, timezone

import pytest

from backend.api.model_stubs import ChallengeBook, ReadingChallenge, UserBook


@pytest.fixture
async def challenge(db_session, test_user):
    c = ReadingChallenge(
        id=str(uuid.uuid4()),
        user_id=test_user.id,
        year=2026,
        goal_count=52,
        current_count=0,
        is_complete=False,
    )
    db_session.add(c)
    await db_session.commit()
    await db_session.refresh(c)
    return c


class TestCreateChallenge:
    async def test_create_challenge(self, client):
        resp = await client.post(
            "/api/v1/me/challenges",
            json={"year": 2026, "goal_count": 52},
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["year"] == 2026
        assert data["goal_count"] == 52
        assert data["current_count"] == 0
        assert data["is_complete"] is False

    async def test_create_duplicate_challenge(self, client, challenge):
        resp = await client.post(
            "/api/v1/me/challenges",
            json={"year": 2026, "goal_count": 100},
        )
        assert resp.status_code == 409

    async def test_create_challenge_validation(self, client):
        resp = await client.post(
            "/api/v1/me/challenges",
            json={"year": 2026, "goal_count": 0},
        )
        assert resp.status_code == 422

        resp = await client.post(
            "/api/v1/me/challenges",
            json={"year": 2026, "goal_count": 501},
        )
        assert resp.status_code == 422


class TestListChallenges:
    async def test_empty_challenges(self, client):
        resp = await client.get("/api/v1/me/challenges")
        assert resp.status_code == 200
        assert resp.json() == []

    async def test_list_challenges(self, client, challenge):
        resp = await client.get("/api/v1/me/challenges")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["year"] == 2026


class TestGetChallenge:
    async def test_get_challenge(self, client, challenge):
        resp = await client.get("/api/v1/me/challenges/2026")
        assert resp.status_code == 200
        data = resp.json()
        assert data["year"] == 2026
        assert data["goal_count"] == 52

    async def test_get_challenge_not_found(self, client):
        resp = await client.get("/api/v1/me/challenges/2025")
        assert resp.status_code == 404

    async def test_get_challenge_with_books(
        self, client, db_session, challenge, test_user, test_work
    ):
        ub = UserBook(
            id=str(uuid.uuid4()),
            user_id=test_user.id,
            work_id=test_work.id,
            status="read",
            finished_at=datetime(2026, 3, 1, tzinfo=timezone.utc),
        )
        db_session.add(ub)
        await db_session.flush()

        cb = ChallengeBook(
            id=str(uuid.uuid4()),
            challenge_id=challenge.id,
            user_book_id=ub.id,
        )
        db_session.add(cb)
        challenge.current_count = 1
        await db_session.commit()

        resp = await client.get("/api/v1/me/challenges/2026")
        assert resp.status_code == 200
        data = resp.json()
        assert data["current_count"] == 1
        assert data["books"] is not None
        assert len(data["books"]) == 1


class TestUpdateChallenge:
    async def test_update_goal(self, client, challenge):
        resp = await client.patch(
            "/api/v1/me/challenges/2026",
            json={"goal_count": 100},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["goal_count"] == 100

    async def test_update_marks_complete(self, client, db_session, challenge):
        challenge.current_count = 10
        await db_session.commit()

        resp = await client.patch(
            "/api/v1/me/challenges/2026",
            json={"goal_count": 5},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["is_complete"] is True
        assert data["completed_at"] is not None

    async def test_update_not_found(self, client):
        resp = await client.patch(
            "/api/v1/me/challenges/2025",
            json={"goal_count": 50},
        )
        assert resp.status_code == 404


class TestViewOtherUserChallenge:
    async def test_view_other_user_challenge(self, client, db_session, other_user):
        c = ReadingChallenge(
            id=str(uuid.uuid4()),
            user_id=other_user.id,
            year=2026,
            goal_count=24,
            current_count=12,
        )
        db_session.add(c)
        await db_session.commit()

        resp = await client.get(f"/api/v1/users/{other_user.id}/challenges/2026")
        assert resp.status_code == 200
        data = resp.json()
        assert data["goal_count"] == 24
        assert data["current_count"] == 12
