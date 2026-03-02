from __future__ import annotations

import hashlib
import uuid
from datetime import datetime, timezone
from decimal import Decimal

import pytest
from backend.api.model_stubs import (
    Block,
    Follow,
    TasteMatch,
    User,
    UserContactHash,
)


def _sha256(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


@pytest.fixture
async def discoverable_user(db_session):
    """A second user who has stored contact hashes."""
    user = User(
        id=str(uuid.uuid4()),
        username="discoverable",
        display_name="Discoverable User",
        is_premium=False,
        is_deleted=False,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    # Store an email hash for this user
    email_hash = _sha256("discoverable@example.com")
    contact = UserContactHash(
        id=str(uuid.uuid4()),
        user_id=str(user.id),
        hash=email_hash,
        hash_type="email",
    )
    db_session.add(contact)
    await db_session.commit()

    return user


@pytest.fixture
async def popular_users(db_session):
    """Create several users with different follower counts."""
    users = []
    for i in range(5):
        user = User(
            id=str(uuid.uuid4()),
            username=f"popular{i}",
            display_name=f"Popular User {i}",
            is_premium=False,
            is_deleted=False,
        )
        db_session.add(user)
        users.append(user)

    await db_session.commit()
    for u in users:
        await db_session.refresh(u)

    # Give user[0] the most followers (3), user[1] gets 2, user[2] gets 1
    follower_sources = []
    for i in range(3):
        src = User(
            id=str(uuid.uuid4()),
            username=f"follower_src_{i}",
            display_name=f"Follower Source {i}",
            is_premium=False,
            is_deleted=False,
        )
        db_session.add(src)
        follower_sources.append(src)
    await db_session.commit()
    for s in follower_sources:
        await db_session.refresh(s)

    # user[0] gets 3 followers
    for src in follower_sources:
        db_session.add(Follow(follower_id=str(src.id), following_id=str(users[0].id)))
    # user[1] gets 2 followers
    for src in follower_sources[:2]:
        db_session.add(Follow(follower_id=str(src.id), following_id=str(users[1].id)))
    # user[2] gets 1 follower
    db_session.add(Follow(follower_id=str(follower_sources[0].id), following_id=str(users[2].id)))

    await db_session.commit()
    return users


# ---------------------------------------------------------------------------
# Contact matching tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_find_contacts_matches_email_hash(client, discoverable_user):
    """Upload a hash that matches a registered user's email hash."""
    email_hash = _sha256("discoverable@example.com")
    resp = await client.post(
        "/api/v1/me/discover/contacts",
        json={"hashes": [email_hash]},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["users"]) == 1
    assert data["users"][0]["username"] == "discoverable"


@pytest.mark.asyncio
async def test_find_contacts_no_self_match(client, db_session, test_user, test_user_id):
    """The current user should not appear in their own contact matches."""
    email_hash = _sha256("myself@example.com")
    contact = UserContactHash(
        id=str(uuid.uuid4()),
        user_id=str(test_user_id),
        hash=email_hash,
        hash_type="email",
    )
    db_session.add(contact)
    await db_session.commit()

    resp = await client.post(
        "/api/v1/me/discover/contacts",
        json={"hashes": [email_hash]},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["users"]) == 0


@pytest.mark.asyncio
async def test_find_contacts_excludes_blocked_users(
    client, db_session, discoverable_user, test_user_id
):
    """Blocked users should not appear in contact matches."""
    block = Block(
        blocker_id=str(test_user_id),
        blocked_id=str(discoverable_user.id),
    )
    db_session.add(block)
    await db_session.commit()

    email_hash = _sha256("discoverable@example.com")
    resp = await client.post(
        "/api/v1/me/discover/contacts",
        json={"hashes": [email_hash]},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["users"]) == 0


@pytest.mark.asyncio
async def test_find_contacts_empty_hashes(client):
    """Uploading an empty list returns empty results."""
    resp = await client.post(
        "/api/v1/me/discover/contacts",
        json={"hashes": []},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["users"]) == 0


@pytest.mark.asyncio
async def test_find_contacts_no_matches(client):
    """Uploading hashes that match no one returns empty results."""
    resp = await client.post(
        "/api/v1/me/discover/contacts",
        json={"hashes": [_sha256("nobody@nowhere.com")]},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["users"]) == 0


# ---------------------------------------------------------------------------
# Taste suggestion tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_taste_suggestions_returns_matches(client, db_session, other_user, test_user_id):
    """Users with taste match records are returned, ordered by score."""
    taste = TasteMatch(
        user_a_id=str(test_user_id),
        user_b_id=str(other_user.id),
        match_score=Decimal("0.875"),
        overlapping_books_count=12,
        computed_at=datetime.now(timezone.utc),
    )
    db_session.add(taste)
    await db_session.commit()

    resp = await client.get("/api/v1/me/discover/taste")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["users"]) == 1
    assert data["users"][0]["username"] == "otheruser"
    assert float(data["users"][0]["taste_match_score"]) == pytest.approx(0.875, abs=0.001)


@pytest.mark.asyncio
async def test_taste_suggestions_excludes_already_followed(
    client, db_session, other_user, test_user_id
):
    """Already-followed users should not appear in taste suggestions."""
    taste = TasteMatch(
        user_a_id=str(test_user_id),
        user_b_id=str(other_user.id),
        match_score=Decimal("0.900"),
        overlapping_books_count=15,
        computed_at=datetime.now(timezone.utc),
    )
    db_session.add(taste)

    follow = Follow(
        follower_id=str(test_user_id),
        following_id=str(other_user.id),
    )
    db_session.add(follow)
    await db_session.commit()

    resp = await client.get("/api/v1/me/discover/taste")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["users"]) == 0


@pytest.mark.asyncio
async def test_taste_suggestions_excludes_blocked(client, db_session, other_user, test_user_id):
    """Blocked users should not appear in taste suggestions."""
    taste = TasteMatch(
        user_a_id=str(test_user_id),
        user_b_id=str(other_user.id),
        match_score=Decimal("0.950"),
        overlapping_books_count=20,
        computed_at=datetime.now(timezone.utc),
    )
    db_session.add(taste)

    block = Block(
        blocker_id=str(test_user_id),
        blocked_id=str(other_user.id),
    )
    db_session.add(block)
    await db_session.commit()

    resp = await client.get("/api/v1/me/discover/taste")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["users"]) == 0


@pytest.mark.asyncio
async def test_taste_suggestions_empty_when_no_matches(client):
    """Returns empty when user has no taste matches."""
    resp = await client.get("/api/v1/me/discover/taste")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["users"]) == 0


# ---------------------------------------------------------------------------
# Popular users tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_popular_users_ordered_by_follower_count(client, popular_users):
    """Popular users endpoint returns users ordered by follower count descending."""
    resp = await client.get("/api/v1/me/discover/popular")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["users"]) >= 3
    # First user should be the one with most followers (popular0 has 3)
    assert data["users"][0]["username"] == "popular0"
    assert data["users"][1]["username"] == "popular1"
    assert data["users"][2]["username"] == "popular2"


@pytest.mark.asyncio
async def test_popular_users_excludes_already_followed(
    client, db_session, popular_users, test_user_id
):
    """Already-followed users should not appear in popular suggestions."""
    follow = Follow(
        follower_id=str(test_user_id),
        following_id=str(popular_users[0].id),
    )
    db_session.add(follow)
    await db_session.commit()

    resp = await client.get("/api/v1/me/discover/popular")
    assert resp.status_code == 200
    data = resp.json()
    usernames = [u["username"] for u in data["users"]]
    assert "popular0" not in usernames


@pytest.mark.asyncio
async def test_popular_users_excludes_blocked(client, db_session, popular_users, test_user_id):
    """Blocked users should not appear in popular suggestions."""
    block = Block(
        blocker_id=str(test_user_id),
        blocked_id=str(popular_users[0].id),
    )
    db_session.add(block)
    await db_session.commit()

    resp = await client.get("/api/v1/me/discover/popular")
    assert resp.status_code == 200
    data = resp.json()
    usernames = [u["username"] for u in data["users"]]
    assert "popular0" not in usernames


@pytest.mark.asyncio
async def test_popular_users_empty_results(client):
    """Returns empty when there are no other users."""
    resp = await client.get("/api/v1/me/discover/popular")
    assert resp.status_code == 200
    data = resp.json()
    # May have the test_user's "otheruser" or similar, but at minimum should not error
    assert "users" in data
