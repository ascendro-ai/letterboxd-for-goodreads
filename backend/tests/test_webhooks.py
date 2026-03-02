"""Tests for webhook endpoints (RevenueCat)."""

import uuid

import pytest

from backend.api.model_stubs import User


class TestRevenueCatWebhook:
    async def test_initial_purchase_grants_premium(self, client, db_session, test_user):
        resp = await client.post(
            "/api/v1/webhooks/revenuecat",
            json={
                "event": {
                    "type": "INITIAL_PURCHASE",
                    "app_user_id": str(test_user.id),
                }
            },
        )
        assert resp.status_code == 200
        assert resp.json()["status"] == "ok"

        await db_session.refresh(test_user)
        assert test_user.is_premium is True

    async def test_renewal_grants_premium(self, client, db_session, test_user):
        resp = await client.post(
            "/api/v1/webhooks/revenuecat",
            json={
                "event": {
                    "type": "RENEWAL",
                    "app_user_id": str(test_user.id),
                }
            },
        )
        assert resp.status_code == 200
        await db_session.refresh(test_user)
        assert test_user.is_premium is True

    async def test_expiration_revokes_premium(self, client, db_session, test_user):
        # First grant premium
        test_user.is_premium = True
        await db_session.commit()

        resp = await client.post(
            "/api/v1/webhooks/revenuecat",
            json={
                "event": {
                    "type": "EXPIRATION",
                    "app_user_id": str(test_user.id),
                }
            },
        )
        assert resp.status_code == 200
        await db_session.refresh(test_user)
        assert test_user.is_premium is False

    async def test_billing_issue_revokes_premium(self, client, db_session, test_user):
        test_user.is_premium = True
        await db_session.commit()

        resp = await client.post(
            "/api/v1/webhooks/revenuecat",
            json={
                "event": {
                    "type": "BILLING_ISSUE",
                    "app_user_id": str(test_user.id),
                }
            },
        )
        assert resp.status_code == 200
        await db_session.refresh(test_user)
        assert test_user.is_premium is False

    async def test_unknown_event_ignored(self, client):
        resp = await client.post(
            "/api/v1/webhooks/revenuecat",
            json={
                "event": {
                    "type": "TEST",
                    "app_user_id": str(uuid.uuid4()),
                }
            },
        )
        assert resp.status_code == 200
        assert resp.json()["status"] == "ok"

    async def test_missing_user_id_ignored(self, client):
        resp = await client.post(
            "/api/v1/webhooks/revenuecat",
            json={
                "event": {
                    "type": "INITIAL_PURCHASE",
                    "app_user_id": "",
                }
            },
        )
        assert resp.status_code == 200
        assert resp.json()["status"] == "ignored"

    async def test_cancellation_no_immediate_revoke(self, client, db_session, test_user):
        """CANCELLATION means user cancelled future renewal, but still has access until period ends."""
        test_user.is_premium = True
        await db_session.commit()

        resp = await client.post(
            "/api/v1/webhooks/revenuecat",
            json={
                "event": {
                    "type": "CANCELLATION",
                    "app_user_id": str(test_user.id),
                }
            },
        )
        assert resp.status_code == 200
        await db_session.refresh(test_user)
        # CANCELLATION is not in grant or revoke lists — premium should remain
        assert test_user.is_premium is True

    async def test_uncancellation_grants_premium(self, client, db_session, test_user):
        resp = await client.post(
            "/api/v1/webhooks/revenuecat",
            json={
                "event": {
                    "type": "UNCANCELLATION",
                    "app_user_id": str(test_user.id),
                }
            },
        )
        assert resp.status_code == 200
        await db_session.refresh(test_user)
        assert test_user.is_premium is True
