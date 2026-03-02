"""Tests for auth route validation and error handling.

Note: Auth routes proxy to Supabase, so we can't test the full flow without
mocking Supabase. These tests verify request validation and our local logic
(username checks, invite code validation, account deletion).
"""

import uuid
from unittest.mock import AsyncMock, patch

import pytest

from backend.api.model_stubs import InviteCode, User


@pytest.fixture
async def invite_code(db_session, other_user):
    code = InviteCode(
        id=str(uuid.uuid4()),
        code="TESTCODE1234",
        created_by_user_id=other_user.id,
    )
    db_session.add(code)
    await db_session.commit()
    await db_session.refresh(code)
    return code


class TestSignupValidation:
    async def test_signup_reserved_username(self, client, invite_code):
        """Reserved usernames like 'admin' should be rejected."""
        resp = await client.post(
            "/api/v1/auth/signup",
            json={
                "email": "test@example.com",
                "password": "password123",
                "username": "admin",
                "invite_code": invite_code.code,
            },
        )
        assert resp.status_code == 422

    async def test_signup_invalid_username_format(self, client, invite_code):
        """Usernames with invalid characters should be rejected."""
        resp = await client.post(
            "/api/v1/auth/signup",
            json={
                "email": "test@example.com",
                "password": "password123",
                "username": "ab",  # too short
                "invite_code": invite_code.code,
            },
        )
        assert resp.status_code == 422

    async def test_signup_duplicate_username(self, client, test_user, invite_code):
        """Duplicate usernames should be rejected."""
        resp = await client.post(
            "/api/v1/auth/signup",
            json={
                "email": "new@example.com",
                "password": "password123",
                "username": test_user.username,
                "invite_code": invite_code.code,
            },
        )
        assert resp.status_code == 409

    async def test_signup_invalid_invite_code(self, client):
        """Invalid invite codes should be rejected."""
        resp = await client.post(
            "/api/v1/auth/signup",
            json={
                "email": "test@example.com",
                "password": "password123",
                "username": "newuser123",
                "invite_code": "FAKECODE9999",
            },
        )
        assert resp.status_code == 422

    async def test_signup_claimed_invite_code(self, client, db_session, invite_code, other_user):
        """Already-claimed invite codes should be rejected."""
        invite_code.claimed_by_user_id = other_user.id
        await db_session.commit()

        resp = await client.post(
            "/api/v1/auth/signup",
            json={
                "email": "test@example.com",
                "password": "password123",
                "username": "newuser456",
                "invite_code": invite_code.code,
            },
        )
        assert resp.status_code == 422


class TestDeleteAccount:
    async def test_delete_requires_confirmation(self, client):
        """Account deletion requires confirm=true."""
        resp = await client.request(
            "DELETE",
            "/api/v1/auth/account",
            json={"confirm": False},
        )
        assert resp.status_code == 422

    async def test_delete_with_confirmation(self, client):
        """Account deletion succeeds with confirm=true."""
        resp = await client.request(
            "DELETE",
            "/api/v1/auth/account",
            json={"confirm": True},
        )
        assert resp.status_code == 204


class TestLoginValidation:
    async def test_login_missing_fields(self, client):
        """Missing email should return validation error."""
        resp = await client.post(
            "/api/v1/auth/login",
            json={"password": "password123"},
        )
        assert resp.status_code == 422

    async def test_login_missing_password(self, client):
        """Missing password should return validation error."""
        resp = await client.post(
            "/api/v1/auth/login",
            json={"email": "test@example.com"},
        )
        assert resp.status_code == 422


class TestRefreshValidation:
    async def test_refresh_missing_token(self, client):
        """Missing refresh token should return validation error."""
        resp = await client.post(
            "/api/v1/auth/refresh",
            json={},
        )
        assert resp.status_code == 422
