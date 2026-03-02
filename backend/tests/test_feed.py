import uuid

import pytest
from backend.api.model_stubs import Activity, Follow, Mute, UserBook, Work


@pytest.mark.asyncio
async def test_feed_empty_no_follows(client):
    """User with no follows gets empty feed (cold start)."""
    resp = await client.get("/api/v1/feed")
    assert resp.status_code == 200
    data = resp.json()
    assert data["items"] == []


@pytest.mark.asyncio
async def test_feed_returns_followed_activities(client, db_session, test_user_id, other_user):
    """Feed should include activities from followed users."""
    # Follow other_user
    follow = Follow(follower_id=str(test_user_id), following_id=str(other_user.id))
    db_session.add(follow)

    # Create a work, user_book, and activity for other_user
    work = Work(id=str(uuid.uuid4()), title="Feed Book", ratings_count=0)
    db_session.add(work)
    await db_session.flush()

    user_book = UserBook(
        id=str(uuid.uuid4()),
        user_id=str(other_user.id),
        work_id=str(work.id),
        status="read",
        is_imported=False,
        has_spoilers=False,
    )
    db_session.add(user_book)
    await db_session.flush()

    activity = Activity(
        id=str(uuid.uuid4()),
        user_id=str(other_user.id),
        activity_type="finished_book",
        target_id=str(user_book.id),
    )
    db_session.add(activity)
    await db_session.commit()

    resp = await client.get("/api/v1/feed")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["items"]) == 1
    assert data["items"][0]["activity_type"] == "finished_book"
    assert data["items"][0]["book"]["title"] == "Feed Book"


@pytest.mark.asyncio
async def test_feed_excludes_muted(client, db_session, test_user_id, other_user):
    """Muted user activities should not appear in feed."""
    follow = Follow(follower_id=str(test_user_id), following_id=str(other_user.id))
    mute = Mute(muter_id=str(test_user_id), muted_id=str(other_user.id))
    db_session.add_all([follow, mute])

    work = Work(id=str(uuid.uuid4()), title="Muted Book", ratings_count=0)
    db_session.add(work)
    await db_session.flush()

    user_book = UserBook(
        id=str(uuid.uuid4()),
        user_id=str(other_user.id),
        work_id=str(work.id),
        status="read",
        is_imported=False,
        has_spoilers=False,
    )
    db_session.add(user_book)
    await db_session.flush()

    activity = Activity(
        id=str(uuid.uuid4()),
        user_id=str(other_user.id),
        activity_type="finished_book",
        target_id=str(user_book.id),
    )
    db_session.add(activity)
    await db_session.commit()

    resp = await client.get("/api/v1/feed")
    assert resp.status_code == 200
    assert len(resp.json()["items"]) == 0


@pytest.mark.asyncio
async def test_notifications_empty(client):
    resp = await client.get("/api/v1/notifications")
    assert resp.status_code == 200
    assert resp.json()["items"] == []
