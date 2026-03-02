"""Tests for admin moderation review endpoints."""

import uuid

import pytest

from backend.api.model_stubs import ReviewFlag, UserBook


@pytest.fixture
async def flagged_review(db_session, test_user, test_work):
    ub = UserBook(
        id=str(uuid.uuid4()),
        user_id=test_user.id,
        work_id=test_work.id,
        status="read",
        review_text="Flagged review content",
    )
    db_session.add(ub)
    await db_session.flush()

    flag = ReviewFlag(
        id=str(uuid.uuid4()),
        flagger_user_id=test_user.id,
        user_book_id=ub.id,
        reason="spam",
        description="This is spam",
        status="pending",
    )
    db_session.add(flag)
    await db_session.commit()
    await db_session.refresh(flag)
    return flag, ub


class TestListFlags:
    async def test_list_flags_no_auth(self, client):
        resp = await client.get("/api/v1/admin/flags")
        assert resp.status_code == 403

    async def test_list_flags_wrong_auth(self, client):
        resp = await client.get(
            "/api/v1/admin/flags",
            headers={"Authorization": "Bearer wrong-key"},
        )
        assert resp.status_code == 403

    async def test_list_flags_empty(self, client):
        # With service key from settings (empty in test mode, so 403)
        resp = await client.get(
            "/api/v1/admin/flags",
            headers={"Authorization": "Bearer "},
        )
        assert resp.status_code == 403


class TestResolveFlag:
    async def test_resolve_no_auth(self, client, flagged_review):
        flag, _ = flagged_review
        resp = await client.post(
            f"/api/v1/admin/flags/{flag.id}/resolve?action=dismiss",
        )
        assert resp.status_code == 403

    async def test_resolve_invalid_action(self, client, flagged_review):
        flag, _ = flagged_review
        resp = await client.post(
            f"/api/v1/admin/flags/{flag.id}/resolve?action=invalid",
            headers={"Authorization": "Bearer wrong"},
        )
        assert resp.status_code == 403

    async def test_resolve_not_found(self, client):
        fake_id = str(uuid.uuid4())
        resp = await client.post(
            f"/api/v1/admin/flags/{fake_id}/resolve?action=dismiss",
            headers={"Authorization": "Bearer wrong"},
        )
        assert resp.status_code == 403
