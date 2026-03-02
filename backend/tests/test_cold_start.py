from __future__ import annotations

import uuid
from decimal import Decimal

import pytest
from backend.api.model_stubs import Activity, Follow, UserBook, Work


@pytest.mark.asyncio
async def test_user_no_follows_gets_popular_feed(client):
    """User with 0 follows gets feed_type = 'popular'."""
    resp = await client.get("/api/v1/feed")
    assert resp.status_code == 200
    data = resp.json()
    assert data["feed_type"] == "popular"


@pytest.mark.asyncio
async def test_user_with_follows_gets_following_feed(client, db_session, test_user_id, other_user):
    """User with follows gets feed_type = 'following'."""
    follow = Follow(follower_id=str(test_user_id), following_id=str(other_user.id))
    db_session.add(follow)

    work = Work(id=str(uuid.uuid4()), title="Followed Book", ratings_count=0)
    db_session.add(work)
    await db_session.flush()

    user_book = UserBook(
        id=str(uuid.uuid4()),
        user_id=str(other_user.id),
        work_id=str(work.id),
        status="read",
        rating=Decimal("4.0"),
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
    assert data["feed_type"] == "following"
    assert len(data["items"]) == 1
    assert data["items"][0]["book"]["title"] == "Followed Book"


@pytest.mark.asyncio
async def test_user_with_follows_but_empty_feed_gets_mixed(
    client, db_session, test_user_id, other_user
):
    """User with follows but no followed-user activity gets feed_type = 'mixed'."""
    follow = Follow(follower_id=str(test_user_id), following_id=str(other_user.id))
    db_session.add(follow)
    await db_session.commit()

    resp = await client.get("/api/v1/feed")
    assert resp.status_code == 200
    data = resp.json()
    assert data["feed_type"] == "mixed"


@pytest.mark.asyncio
async def test_popular_feed_returns_rated_activities(client, db_session, other_user):
    """Popular feed only includes activities with ratings."""
    work = Work(id=str(uuid.uuid4()), title="Rated Book", ratings_count=5)
    db_session.add(work)
    await db_session.flush()

    # User book WITH a rating
    ub_rated = UserBook(
        id=str(uuid.uuid4()),
        user_id=str(other_user.id),
        work_id=str(work.id),
        status="read",
        rating=Decimal("4.5"),
        is_imported=False,
        has_spoilers=False,
    )
    db_session.add(ub_rated)
    await db_session.flush()

    activity_rated = Activity(
        id=str(uuid.uuid4()),
        user_id=str(other_user.id),
        activity_type="finished_book",
        target_id=str(ub_rated.id),
    )
    db_session.add(activity_rated)

    # User book WITHOUT a rating (should be filtered out of popular feed)
    work2 = Work(id=str(uuid.uuid4()), title="Unrated Book", ratings_count=0)
    db_session.add(work2)
    await db_session.flush()

    ub_unrated = UserBook(
        id=str(uuid.uuid4()),
        user_id=str(other_user.id),
        work_id=str(work2.id),
        status="read",
        rating=None,
        is_imported=False,
        has_spoilers=False,
    )
    db_session.add(ub_unrated)
    await db_session.flush()

    activity_unrated = Activity(
        id=str(uuid.uuid4()),
        user_id=str(other_user.id),
        activity_type="finished_book",
        target_id=str(ub_unrated.id),
    )
    db_session.add(activity_unrated)
    await db_session.commit()

    resp = await client.get("/api/v1/feed")
    assert resp.status_code == 200
    data = resp.json()
    assert data["feed_type"] == "popular"

    titles = [item["book"]["title"] for item in data["items"]]
    assert "Rated Book" in titles
    assert "Unrated Book" not in titles


@pytest.mark.asyncio
async def test_popular_feed_pagination(client, db_session, other_user):
    """Popular feed supports cursor pagination."""
    work = Work(id=str(uuid.uuid4()), title="Paginated Book", ratings_count=10)
    db_session.add(work)
    await db_session.flush()

    # Create 3 activities with ratings
    for _i in range(3):
        ub = UserBook(
            id=str(uuid.uuid4()),
            user_id=str(other_user.id),
            work_id=str(work.id),
            status="read",
            rating=Decimal("3.0"),
            is_imported=False,
            has_spoilers=False,
        )
        db_session.add(ub)
        await db_session.flush()

        activity = Activity(
            id=str(uuid.uuid4()),
            user_id=str(other_user.id),
            activity_type="finished_book",
            target_id=str(ub.id),
        )
        db_session.add(activity)

    await db_session.commit()

    # First page with limit=2
    resp = await client.get("/api/v1/feed", params={"limit": 2})
    assert resp.status_code == 200
    data = resp.json()
    assert data["feed_type"] == "popular"
    assert data["has_more"] is True
    assert data["next_cursor"] is not None

    # Second page
    resp2 = await client.get(
        "/api/v1/feed",
        params={"limit": 2, "cursor": data["next_cursor"]},
    )
    assert resp2.status_code == 200
    data2 = resp2.json()
    assert data2["feed_type"] == "popular"
    assert len(data2["items"]) >= 1


@pytest.mark.asyncio
async def test_feed_response_has_feed_type_field(client):
    """Verify feed_type is always present in response."""
    resp = await client.get("/api/v1/feed")
    assert resp.status_code == 200
    data = resp.json()
    assert "feed_type" in data
    assert data["feed_type"] in ("following", "popular", "mixed")
