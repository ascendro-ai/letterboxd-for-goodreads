from __future__ import annotations

import uuid

import pytest
from backend.api.model_stubs import (
    Activity,
    Block,
    Follow,
    Mute,
    Notification,
    Shelf,
    ShelfBook,
    User,
    UserBook,
)
from backend.services.user_service import soft_delete_account
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
async def user_with_social(db_session, test_user, other_user, test_work):
    """Set up a user with follows, blocks, mutes, activities, notifications,
    shelves, and a book log."""
    user_id = test_user.id
    other_id = other_user.id

    # Follow in both directions
    db_session.add(Follow(follower_id=user_id, following_id=other_id))
    db_session.add(Follow(follower_id=other_id, following_id=user_id))

    # Block from user
    db_session.add(Block(blocker_id=user_id, blocked_id=other_id))

    # Mute
    db_session.add(Mute(muter_id=user_id, muted_id=other_id))

    # Activity
    activity = Activity(
        id=str(uuid.uuid4()),
        user_id=user_id,
        activity_type="finished_book",
        target_id=str(uuid.uuid4()),
    )
    db_session.add(activity)

    # Notification (to user)
    notification = Notification(
        id=str(uuid.uuid4()),
        user_id=user_id,
        type="new_follower",
        actor_id=other_id,
    )
    db_session.add(notification)

    # Notification (from user as actor to other)
    notification_from = Notification(
        id=str(uuid.uuid4()),
        user_id=other_id,
        type="new_follower",
        actor_id=user_id,
    )
    db_session.add(notification_from)

    # User book (review + rating)
    user_book = UserBook(
        id=str(uuid.uuid4()),
        user_id=user_id,
        work_id=test_work.id,
        status="read",
        rating=4.5,
        review_text="A wonderful book that changed my perspective.",
        has_spoilers=False,
        is_imported=False,
    )
    db_session.add(user_book)

    # Shelf with a book
    shelf = Shelf(
        id=str(uuid.uuid4()),
        user_id=user_id,
        name="Favorites",
        slug="favorites",
        is_public=True,
    )
    db_session.add(shelf)
    await db_session.flush()

    shelf_book = ShelfBook(
        shelf_id=shelf.id,
        user_book_id=user_book.id,
        position=0,
    )
    db_session.add(shelf_book)

    await db_session.commit()

    return {
        "user": test_user,
        "other_user": other_user,
        "user_book": user_book,
        "shelf": shelf,
        "activity": activity,
    }


# ---------------------------------------------------------------------------
# Unit / service tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_full_anonymization(db_session: AsyncSession, user_with_social):
    """After soft_delete_account, user profile should be fully anonymized."""
    user = user_with_social["user"]
    await soft_delete_account(db_session, user.id)
    await db_session.commit()

    result = await db_session.execute(select(User).where(User.id == user.id))
    deleted_user = result.scalar_one()

    assert deleted_user.is_deleted is True
    assert deleted_user.deleted_at is not None
    assert deleted_user.username.startswith("deleted_")
    assert deleted_user.display_name == "Deleted User"
    assert deleted_user.bio is None
    assert deleted_user.avatar_url is None


@pytest.mark.asyncio
async def test_reviews_persist_after_deletion(db_session: AsyncSession, user_with_social):
    """Reviews and ratings should remain intact after account deletion."""
    user = user_with_social["user"]
    user_book = user_with_social["user_book"]

    await soft_delete_account(db_session, user.id)
    await db_session.commit()

    result = await db_session.execute(select(UserBook).where(UserBook.id == user_book.id))
    ub = result.scalar_one_or_none()

    assert ub is not None
    assert ub.review_text == "A wonderful book that changed my perspective."
    assert float(ub.rating) == 4.5
    assert ub.status == "read"


@pytest.mark.asyncio
async def test_follows_removed_both_directions(db_session: AsyncSession, user_with_social):
    """All follows involving the deleted user should be removed."""
    user = user_with_social["user"]

    await soft_delete_account(db_session, user.id)
    await db_session.commit()

    result = await db_session.execute(select(Follow).where(Follow.follower_id == user.id))
    assert result.scalar_one_or_none() is None

    result = await db_session.execute(select(Follow).where(Follow.following_id == user.id))
    assert result.scalar_one_or_none() is None


@pytest.mark.asyncio
async def test_blocks_removed_both_directions(db_session: AsyncSession, user_with_social):
    """All blocks involving the deleted user should be removed."""
    user = user_with_social["user"]

    await soft_delete_account(db_session, user.id)
    await db_session.commit()

    result = await db_session.execute(
        select(Block).where((Block.blocker_id == user.id) | (Block.blocked_id == user.id))
    )
    assert result.scalar_one_or_none() is None


@pytest.mark.asyncio
async def test_mutes_removed(db_session: AsyncSession, user_with_social):
    """All mutes involving the deleted user should be removed."""
    user = user_with_social["user"]

    await soft_delete_account(db_session, user.id)
    await db_session.commit()

    result = await db_session.execute(
        select(Mute).where((Mute.muter_id == user.id) | (Mute.muted_id == user.id))
    )
    assert result.scalar_one_or_none() is None


@pytest.mark.asyncio
async def test_activities_deleted(db_session: AsyncSession, user_with_social):
    """All feed activities by the deleted user should be removed."""
    user = user_with_social["user"]

    await soft_delete_account(db_session, user.id)
    await db_session.commit()

    result = await db_session.execute(select(Activity).where(Activity.user_id == user.id))
    assert list(result.scalars().all()) == []


@pytest.mark.asyncio
async def test_notifications_cleared(db_session: AsyncSession, user_with_social):
    """Notifications to and from the deleted user should be removed."""
    user = user_with_social["user"]

    await soft_delete_account(db_session, user.id)
    await db_session.commit()

    result = await db_session.execute(select(Notification).where(Notification.user_id == user.id))
    assert list(result.scalars().all()) == []

    result = await db_session.execute(select(Notification).where(Notification.actor_id == user.id))
    assert list(result.scalars().all()) == []


@pytest.mark.asyncio
async def test_shelves_deleted(db_session: AsyncSession, user_with_social):
    """All shelves and shelf_books should be deleted."""
    user = user_with_social["user"]
    shelf = user_with_social["shelf"]

    await soft_delete_account(db_session, user.id)
    await db_session.commit()

    result = await db_session.execute(select(Shelf).where(Shelf.user_id == user.id))
    assert result.scalar_one_or_none() is None

    result = await db_session.execute(select(ShelfBook).where(ShelfBook.shelf_id == shelf.id))
    assert result.scalar_one_or_none() is None


@pytest.mark.asyncio
async def test_user_not_found_raises(db_session: AsyncSession):
    """Deleting a nonexistent user should raise user_not_found."""
    from backend.api.errors import AppError

    with pytest.raises(AppError) as exc_info:
        await soft_delete_account(db_session, uuid.uuid4())

    assert exc_info.value.status_code == 404


# ---------------------------------------------------------------------------
# Integration tests -- DELETE /auth/account endpoint
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_delete_account_requires_confirmation(client):
    """Missing or false 'confirm' field should return 422."""
    resp = await client.request(
        "DELETE",
        "/api/v1/auth/account",
        json={"confirm": False},
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_delete_account_success(client, db_session, test_user):
    """Confirmed deletion should return 204 and anonymize the user."""
    resp = await client.request(
        "DELETE",
        "/api/v1/auth/account",
        json={"confirm": True},
    )
    assert resp.status_code == 204

    result = await db_session.execute(select(User).where(User.id == test_user.id))
    user = result.scalar_one()
    assert user.is_deleted is True
    assert user.username.startswith("deleted_")
    assert user.display_name == "Deleted User"
    assert user.bio is None
    assert user.avatar_url is None
