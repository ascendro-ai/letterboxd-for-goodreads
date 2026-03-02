from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import pytest
from backend.api.model_stubs import InviteCode, User
from backend.services.invite_service import (
    generate_code,
    generate_codes_for_user,
    get_user_invite_codes,
    join_waitlist,
    validate_and_claim_code,
)

# ---------------------------------------------------------------------------
# Unit tests — generate_code
# ---------------------------------------------------------------------------


class TestGenerateCode:
    def test_code_length(self):
        code = generate_code()
        assert len(code) == 8

    def test_code_is_alphanumeric_uppercase(self):
        for _ in range(100):
            code = generate_code()
            assert code.isalnum()
            assert code == code.upper()

    def test_codes_are_unique(self):
        codes = {generate_code() for _ in range(100)}
        assert len(codes) == 100


# ---------------------------------------------------------------------------
# Unit tests — join_waitlist
# ---------------------------------------------------------------------------


class TestJoinWaitlist:
    @pytest.mark.asyncio
    async def test_join_waitlist_happy_path(self, db_session):
        entry = await join_waitlist(db=db_session, email="reader@example.com")
        assert entry.email == "reader@example.com"

    @pytest.mark.asyncio
    async def test_join_waitlist_normalizes_email(self, db_session):
        entry = await join_waitlist(db=db_session, email="  Reader@Example.COM  ")
        assert entry.email == "reader@example.com"

    @pytest.mark.asyncio
    async def test_join_waitlist_duplicate_email_raises(self, db_session):
        await join_waitlist(db=db_session, email="dupe@example.com")
        with pytest.raises(Exception) as exc_info:
            await join_waitlist(db=db_session, email="dupe@example.com")
        assert "WAITLIST_DUPLICATE" in str(exc_info.value)


# ---------------------------------------------------------------------------
# Unit tests — generate_codes_for_user
# ---------------------------------------------------------------------------


class TestGenerateCodesForUser:
    @pytest.mark.asyncio
    async def test_generates_correct_count(self, db_session, test_user):
        codes = await generate_codes_for_user(db=db_session, user_id=test_user.id, count=5)
        assert len(codes) == 5

    @pytest.mark.asyncio
    async def test_codes_belong_to_user(self, db_session, test_user):
        codes = await generate_codes_for_user(db=db_session, user_id=test_user.id)
        for code in codes:
            assert str(code.created_by_user_id) == str(test_user.id)

    @pytest.mark.asyncio
    async def test_codes_are_unclaimed(self, db_session, test_user):
        codes = await generate_codes_for_user(db=db_session, user_id=test_user.id)
        for code in codes:
            assert code.claimed_by_user_id is None
            assert code.claimed_at is None

    @pytest.mark.asyncio
    async def test_all_codes_unique(self, db_session, test_user):
        codes = await generate_codes_for_user(db=db_session, user_id=test_user.id, count=10)
        code_strings = [c.code for c in codes]
        assert len(set(code_strings)) == len(code_strings)


# ---------------------------------------------------------------------------
# Unit tests — validate_and_claim_code
# ---------------------------------------------------------------------------


class TestValidateAndClaimCode:
    @pytest.mark.asyncio
    async def test_claim_valid_code(self, db_session, test_user, other_user):
        invite = InviteCode(
            id=str(uuid.uuid4()),
            code="TESTCODE",
            created_by_user_id=test_user.id,
        )
        db_session.add(invite)
        await db_session.flush()

        result = await validate_and_claim_code(
            db=db_session, code="TESTCODE", user_id=other_user.id
        )
        assert str(result.claimed_by_user_id) == str(other_user.id)
        assert result.claimed_at is not None

    @pytest.mark.asyncio
    async def test_claim_already_claimed_code_raises(self, db_session, test_user, other_user):
        invite = InviteCode(
            id=str(uuid.uuid4()),
            code="CLAIMED1",
            created_by_user_id=test_user.id,
        )
        db_session.add(invite)
        await db_session.flush()

        await validate_and_claim_code(db=db_session, code="CLAIMED1", user_id=other_user.id)

        third_user = User(
            id=str(uuid.uuid4()),
            username="thirduser",
            display_name="Third",
            is_premium=False,
            is_deleted=False,
        )
        db_session.add(third_user)
        await db_session.flush()

        with pytest.raises(Exception) as exc_info:
            await validate_and_claim_code(db=db_session, code="CLAIMED1", user_id=third_user.id)
        assert "INVITE_CODE_CLAIMED" in str(exc_info.value)

    @pytest.mark.asyncio
    async def test_claim_expired_code_raises(self, db_session, test_user, other_user):
        invite = InviteCode(
            id=str(uuid.uuid4()),
            code="EXPIRED1",
            created_by_user_id=test_user.id,
            expires_at=datetime.now(timezone.utc) - timedelta(days=1),
        )
        db_session.add(invite)
        await db_session.flush()

        with pytest.raises(Exception) as exc_info:
            await validate_and_claim_code(db=db_session, code="EXPIRED1", user_id=other_user.id)
        assert "INVITE_CODE_EXPIRED" in str(exc_info.value)

    @pytest.mark.asyncio
    async def test_claim_nonexistent_code_raises(self, db_session, other_user):
        with pytest.raises(Exception) as exc_info:
            await validate_and_claim_code(db=db_session, code="DOESNOTEXIST", user_id=other_user.id)
        assert "INVITE_CODE_INVALID" in str(exc_info.value)

    @pytest.mark.asyncio
    async def test_claim_code_case_insensitive(self, db_session, test_user, other_user):
        invite = InviteCode(
            id=str(uuid.uuid4()),
            code="ABCD1234",
            created_by_user_id=test_user.id,
        )
        db_session.add(invite)
        await db_session.flush()

        result = await validate_and_claim_code(
            db=db_session, code="abcd1234", user_id=other_user.id
        )
        assert str(result.claimed_by_user_id) == str(other_user.id)


# ---------------------------------------------------------------------------
# Unit tests — get_user_invite_codes
# ---------------------------------------------------------------------------


class TestGetUserInviteCodes:
    @pytest.mark.asyncio
    async def test_returns_user_codes(self, db_session, test_user):
        codes = await generate_codes_for_user(db=db_session, user_id=test_user.id, count=3)
        fetched = await get_user_invite_codes(db=db_session, user_id=test_user.id)
        assert len(fetched) == 3
        fetched_codes = {c.code for c in fetched}
        for code in codes:
            assert code.code in fetched_codes

    @pytest.mark.asyncio
    async def test_does_not_return_other_users_codes(self, db_session, test_user, other_user):
        await generate_codes_for_user(db=db_session, user_id=test_user.id, count=3)
        await generate_codes_for_user(db=db_session, user_id=other_user.id, count=2)

        fetched = await get_user_invite_codes(db=db_session, user_id=test_user.id)
        assert len(fetched) == 3
        for code in fetched:
            assert str(code.created_by_user_id) == str(test_user.id)


# ---------------------------------------------------------------------------
# Integration tests — POST /waitlist
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_join_waitlist_endpoint(client):
    response = await client.post(
        "/api/v1/waitlist",
        json={"email": "newreader@example.com"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["email"] == "newreader@example.com"
    assert "position" in body
    assert body["position"] >= 1


@pytest.mark.asyncio
async def test_join_waitlist_duplicate_returns_409(client):
    await client.post(
        "/api/v1/waitlist",
        json={"email": "repeat@example.com"},
    )
    response = await client.post(
        "/api/v1/waitlist",
        json={"email": "repeat@example.com"},
    )
    assert response.status_code == 409
    assert response.json()["detail"]["error"]["code"] == "WAITLIST_DUPLICATE"


# ---------------------------------------------------------------------------
# Integration tests — GET /me/invite-codes
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_list_invite_codes(client, db_session, test_user):
    # Generate codes for the test user
    await generate_codes_for_user(db=db_session, user_id=test_user.id, count=3)
    await db_session.commit()

    response = await client.get("/api/v1/me/invite-codes")
    assert response.status_code == 200
    body = response.json()
    assert isinstance(body, list)
    assert len(body) == 3
    for code_item in body:
        assert "code" in code_item
        assert "created_at" in code_item
        assert "is_claimed" in code_item
        assert "claimed_by_username" in code_item
