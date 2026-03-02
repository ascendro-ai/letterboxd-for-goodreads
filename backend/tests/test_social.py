import uuid

import pytest
from backend.api.model_stubs import Follow


@pytest.mark.asyncio
async def test_follow_user(client, other_user):
    resp = await client.post(f"/api/v1/users/{other_user.id}/follow")
    assert resp.status_code == 201


@pytest.mark.asyncio
async def test_follow_already_following(client, other_user):
    await client.post(f"/api/v1/users/{other_user.id}/follow")

    resp = await client.post(f"/api/v1/users/{other_user.id}/follow")
    assert resp.status_code == 409
    assert resp.json()["detail"]["error"]["code"] == "ALREADY_FOLLOWING"


@pytest.mark.asyncio
async def test_unfollow_user(client, other_user):
    await client.post(f"/api/v1/users/{other_user.id}/follow")

    resp = await client.delete(f"/api/v1/users/{other_user.id}/follow")
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_unfollow_not_following(client, other_user):
    resp = await client.delete(f"/api/v1/users/{other_user.id}/follow")
    assert resp.status_code == 409
    assert resp.json()["detail"]["error"]["code"] == "NOT_FOLLOWING"


@pytest.mark.asyncio
async def test_block_user(client, other_user):
    resp = await client.post(f"/api/v1/users/{other_user.id}/block")
    assert resp.status_code == 201


@pytest.mark.asyncio
async def test_block_auto_unfollows(client, db_session, other_user, test_user_id):
    """Blocking should auto-remove follows in both directions."""
    # Follow the other user
    await client.post(f"/api/v1/users/{other_user.id}/follow")

    # Also add reverse follow
    reverse_follow = Follow(follower_id=str(other_user.id), following_id=str(test_user_id))
    db_session.add(reverse_follow)
    await db_session.commit()

    # Block
    resp = await client.post(f"/api/v1/users/{other_user.id}/block")
    assert resp.status_code == 201

    # Verify follows are gone
    from sqlalchemy import select

    result = await db_session.execute(
        select(Follow).where(
            (
                (Follow.follower_id == str(test_user_id))
                & (Follow.following_id == str(other_user.id))
            )
            | (
                (Follow.follower_id == str(other_user.id))
                & (Follow.following_id == str(test_user_id))
            )
        )
    )
    follows = result.scalars().all()
    assert len(follows) == 0


@pytest.mark.asyncio
async def test_block_prevents_follow(client, other_user):
    """After blocking, follow should fail."""
    await client.post(f"/api/v1/users/{other_user.id}/block")

    resp = await client.post(f"/api/v1/users/{other_user.id}/follow")
    assert resp.status_code == 403
    assert resp.json()["detail"]["error"]["code"] == "BLOCKED_USER"


@pytest.mark.asyncio
async def test_mute_user(client, other_user):
    resp = await client.post(f"/api/v1/users/{other_user.id}/mute")
    assert resp.status_code == 201


@pytest.mark.asyncio
async def test_unmute_user(client, other_user):
    await client.post(f"/api/v1/users/{other_user.id}/mute")

    resp = await client.delete(f"/api/v1/users/{other_user.id}/mute")
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_self_follow_fails(client, test_user_id):
    resp = await client.post(f"/api/v1/users/{test_user_id}/follow")
    assert resp.status_code == 400
    assert resp.json()["detail"]["error"]["code"] == "SELF_ACTION"


@pytest.mark.asyncio
async def test_follow_nonexistent_user(client):
    fake_id = uuid.uuid4()
    resp = await client.post(f"/api/v1/users/{fake_id}/follow")
    assert resp.status_code == 404
