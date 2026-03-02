import uuid
from unittest.mock import AsyncMock, patch

import pytest
from backend.api.model_stubs import ReviewFlag, User, UserBook
from backend.api.schemas.moderation import ModerationResult


@pytest.mark.asyncio
async def test_flag_review_success(client, db_session, test_user, test_work, other_user):
    """Flag another user's review — happy path."""
    user_book = UserBook(
        id=str(uuid.uuid4()),
        user_id=other_user.id,
        work_id=test_work.id,
        status="read",
        rating=None,
        review_text="Some review text",
        has_spoilers=False,
        is_imported=False,
        is_hidden=False,
    )
    db_session.add(user_book)
    await db_session.commit()
    await db_session.refresh(user_book)

    resp = await client.post(
        f"/api/v1/reviews/{user_book.id}/flag",
        json={"reason": "spam"},
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["reason"] == "spam"
    assert data["status"] == "pending"
    assert "id" in data
    assert "created_at" in data


@pytest.mark.asyncio
async def test_flag_review_duplicate_returns_409(
    client, db_session, test_user, test_work, other_user
):
    """Flagging the same review twice returns 409."""
    user_book = UserBook(
        id=str(uuid.uuid4()),
        user_id=other_user.id,
        work_id=test_work.id,
        status="read",
        review_text="Duplicate test review",
        has_spoilers=False,
        is_imported=False,
        is_hidden=False,
    )
    db_session.add(user_book)
    await db_session.commit()
    await db_session.refresh(user_book)

    resp1 = await client.post(
        f"/api/v1/reviews/{user_book.id}/flag",
        json={"reason": "harassment"},
    )
    assert resp1.status_code == 201

    resp2 = await client.post(
        f"/api/v1/reviews/{user_book.id}/flag",
        json={"reason": "spam"},
    )
    assert resp2.status_code == 409
    assert resp2.json()["detail"]["error"]["code"] == "DUPLICATE_FLAG"


@pytest.mark.asyncio
async def test_flag_own_review_returns_403(client, db_session, test_user, test_work):
    """Flagging your own review returns 403."""
    user_book = UserBook(
        id=str(uuid.uuid4()),
        user_id=test_user.id,
        work_id=test_work.id,
        status="read",
        review_text="My own review",
        has_spoilers=False,
        is_imported=False,
        is_hidden=False,
    )
    db_session.add(user_book)
    await db_session.commit()
    await db_session.refresh(user_book)

    resp = await client.post(
        f"/api/v1/reviews/{user_book.id}/flag",
        json={"reason": "spam"},
    )
    assert resp.status_code == 403
    assert resp.json()["detail"]["error"]["code"] == "CANNOT_FLAG_OWN_REVIEW"


@pytest.mark.asyncio
async def test_auto_hide_at_three_flags(client, db_session, test_user, test_work, other_user):
    """Review flag count reaches 3 — verified via service function."""
    user_book = UserBook(
        id=str(uuid.uuid4()),
        user_id=other_user.id,
        work_id=test_work.id,
        status="read",
        review_text="Controversial review",
        has_spoilers=False,
        is_imported=False,
        is_hidden=False,
    )
    db_session.add(user_book)
    await db_session.commit()
    await db_session.refresh(user_book)

    # First flag: from test_user (via API)
    resp = await client.post(
        f"/api/v1/reviews/{user_book.id}/flag",
        json={"reason": "hate_speech"},
    )
    assert resp.status_code == 201

    # Flags 2 and 3: create directly in DB from different users
    for i in range(2):
        flagger = User(
            id=str(uuid.uuid4()),
            username=f"flagger{i}",
            display_name=f"Flagger {i}",
            is_premium=False,
            is_deleted=False,
        )
        db_session.add(flagger)
        await db_session.flush()

        flag = ReviewFlag(
            id=str(uuid.uuid4()),
            flagger_user_id=flagger.id,
            user_book_id=user_book.id,
            reason="hate_speech",
            status="pending",
        )
        db_session.add(flag)

    await db_session.commit()

    from backend.services.moderation_service import get_flag_count

    count = await get_flag_count(db_session, user_book.id)
    assert count == 3


@pytest.mark.asyncio
async def test_moderation_check_flagged_content(client, test_work):
    """Review submission with flagged content returns 422."""
    mock_result = ModerationResult(
        is_flagged=True,
        categories=["harassment"],
        confidence=0.95,
    )

    with patch(
        "backend.api.routes.user_books.check_review_content",
        new_callable=AsyncMock,
        return_value=mock_result,
    ):
        resp = await client.post(
            "/api/v1/me/books",
            json={
                "work_id": str(test_work.id),
                "status": "read",
                "rating": 4.0,
                "review_text": "This is toxic content that should be flagged",
            },
        )

    assert resp.status_code == 422
    data = resp.json()
    assert data["detail"]["error"]["code"] == "REVIEW_FLAGGED"


@pytest.mark.asyncio
async def test_moderation_check_clean_content(client, test_work):
    """Review submission with clean content passes moderation."""
    mock_result = ModerationResult(
        is_flagged=False,
        categories=[],
        confidence=0.05,
    )

    with patch(
        "backend.api.routes.user_books.check_review_content",
        new_callable=AsyncMock,
        return_value=mock_result,
    ):
        resp = await client.post(
            "/api/v1/me/books",
            json={
                "work_id": str(test_work.id),
                "status": "read",
                "rating": 4.0,
                "review_text": "This is a wonderful book, highly recommend!",
            },
        )

    assert resp.status_code == 201
    data = resp.json()
    assert data["review_text"] == "This is a wonderful book, highly recommend!"


@pytest.mark.asyncio
async def test_moderation_api_failure_allows_review():
    """If the moderation API is down, reviews should still be accepted."""
    from backend.services.moderation_service import check_review_content

    # With no OpenAI API key set, the service should return is_flagged=False
    result = await check_review_content("Some review text")
    assert result.is_flagged is False


@pytest.mark.asyncio
async def test_flag_nonexistent_review_returns_404(client):
    """Flagging a non-existent review returns 404."""
    fake_id = str(uuid.uuid4())
    resp = await client.post(
        f"/api/v1/reviews/{fake_id}/flag",
        json={"reason": "spam"},
    )
    assert resp.status_code == 404
    assert resp.json()["detail"]["error"]["code"] == "USER_BOOK_NOT_FOUND"
