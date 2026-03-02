"""Tests for push notification endpoints and service."""

import uuid
from unittest.mock import AsyncMock, patch

import pytest

from backend.api.model_stubs import DeviceToken, Notification


@pytest.fixture
async def device_token(db_session, test_user):
    token = DeviceToken(
        id=str(uuid.uuid4()),
        user_id=test_user.id,
        token="abc123devicetoken",
        platform="ios",
    )
    db_session.add(token)
    await db_session.commit()
    return token


@pytest.fixture
async def notification(db_session, test_user):
    notif = Notification(
        id=str(uuid.uuid4()),
        user_id=test_user.id,
        type="new_follower",
        is_read=False,
    )
    db_session.add(notif)
    await db_session.commit()
    await db_session.refresh(notif)
    return notif


class TestRegisterDevice:
    async def test_register_device(self, client):
        resp = await client.post(
            "/api/v1/me/devices",
            json={"device_token": "new-token-123", "platform": "ios"},
        )
        assert resp.status_code == 201
        assert resp.json()["status"] == "registered"

    async def test_register_device_missing_token(self, client):
        resp = await client.post(
            "/api/v1/me/devices",
            json={"device_token": "", "platform": "ios"},
        )
        assert resp.status_code == 422


class TestUnregisterDevice:
    async def test_unregister_device(self, client, device_token):
        resp = await client.request(
            "DELETE",
            "/api/v1/me/devices",
            json={"device_token": device_token.token},
        )
        assert resp.status_code == 200
        assert resp.json()["status"] == "unregistered"


class TestListNotifications:
    async def test_empty_notifications(self, client):
        resp = await client.get("/api/v1/notifications")
        assert resp.status_code == 200
        data = resp.json()
        assert data["items"] == []
        assert data["has_more"] is False

    async def test_with_notifications(self, client, notification):
        resp = await client.get("/api/v1/notifications")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["items"]) == 1
        assert data["items"][0]["type"] == "new_follower"
        assert data["items"][0]["is_read"] is False


class TestMarkRead:
    async def test_mark_read(self, client, notification):
        resp = await client.post(
            "/api/v1/notifications/read",
            json={"notification_ids": [str(notification.id)]},
        )
        assert resp.status_code == 200
        assert resp.json()["message"] == "Notifications marked as read"

    async def test_mark_read_empty_list(self, client):
        resp = await client.post(
            "/api/v1/notifications/read",
            json={"notification_ids": []},
        )
        assert resp.status_code == 200
        assert resp.json()["message"] == "Notifications marked as read"


class TestUnreadCount:
    async def test_unread_count_zero(self, client):
        resp = await client.get("/api/v1/notifications/unread-count")
        assert resp.status_code == 200
        assert resp.json()["count"] == 0

    async def test_unread_count_with_notifications(self, client, notification):
        resp = await client.get("/api/v1/notifications/unread-count")
        assert resp.status_code == 200
        assert resp.json()["count"] == 1
