"""Social graph service: follow, block, mute, and taste matches.

Block semantics: blocking auto-unfollows in both directions and removes any
mutes, ensuring complete separation. is_blocked() checks both directions --
if either party has blocked the other, they can't interact.
"""

from __future__ import annotations

from uuid import UUID

from backend.api.errors import (
    already_following,
    blocked_user,
    not_following,
    self_action,
    user_not_found,
)
from backend.api.model_stubs import (
    Block,
    Follow,
    Mute,
    Notification,
    TasteMatch,
    User,
)
from backend.api.pagination import encode_cursor
from backend.api.schemas.common import PaginatedResponse
from backend.api.schemas.social import TasteMatchResponse
from backend.api.schemas.users import UserBrief
from sqlalchemy import and_, delete, or_, select
from sqlalchemy.ext.asyncio import AsyncSession


async def is_blocked(db: AsyncSession, user_a: UUID, user_b: UUID) -> bool:
    """Check if either user has blocked the other."""
    result = await db.execute(
        select(Block).where(
            or_(
                and_(Block.blocker_id == user_a, Block.blocked_id == user_b),
                and_(Block.blocker_id == user_b, Block.blocked_id == user_a),
            )
        )
    )
    return result.scalar_one_or_none() is not None


async def follow_user(db: AsyncSession, follower_id: UUID, target_id: UUID) -> None:
    """Follow a user. Block and self-action checks."""
    if str(follower_id) == str(target_id):
        raise self_action()

    # Verify target exists
    target = await db.execute(
        select(User).where(User.id == target_id, User.is_deleted == False)  # noqa: E712
    )
    if target.scalar_one_or_none() is None:
        raise user_not_found()

    if await is_blocked(db, follower_id, target_id):
        raise blocked_user()

    # Check if already following
    existing = await db.execute(
        select(Follow).where(Follow.follower_id == follower_id, Follow.following_id == target_id)
    )
    if existing.scalar_one_or_none() is not None:
        raise already_following()

    follow = Follow(follower_id=follower_id, following_id=target_id)
    db.add(follow)

    # Create notification
    notification = Notification(
        user_id=target_id,
        type="new_follower",
        actor_id=follower_id,
    )
    db.add(notification)

    await db.flush()


async def unfollow_user(db: AsyncSession, follower_id: UUID, target_id: UUID) -> None:
    """Unfollow a user."""
    result = await db.execute(
        select(Follow).where(Follow.follower_id == follower_id, Follow.following_id == target_id)
    )
    follow = result.scalar_one_or_none()
    if follow is None:
        raise not_following()

    await db.delete(follow)
    await db.flush()


async def list_followers(
    db: AsyncSession, user_id: UUID, cursor: str | None, limit: int
) -> PaginatedResponse[UserBrief]:
    """List a user's followers."""
    stmt = (
        select(User)
        .join(Follow, Follow.follower_id == User.id)
        .where(Follow.following_id == user_id, User.is_deleted == False)  # noqa: E712
        .order_by(Follow.created_at.desc())
    )
    stmt = stmt.limit(limit + 1)

    result = await db.execute(stmt)
    users = list(result.scalars().all())

    has_more = len(users) > limit
    if has_more:
        users = users[:limit]

    items = [
        UserBrief(
            id=u.id, username=u.username, display_name=u.display_name, avatar_url=u.avatar_url
        )
        for u in users
    ]

    next_cursor = encode_cursor(users[-1].created_at, users[-1].id) if has_more else None
    return PaginatedResponse(items=items, next_cursor=next_cursor, has_more=has_more)


async def list_following(
    db: AsyncSession, user_id: UUID, cursor: str | None, limit: int
) -> PaginatedResponse[UserBrief]:
    """List users that a user follows."""
    stmt = (
        select(User)
        .join(Follow, Follow.following_id == User.id)
        .where(Follow.follower_id == user_id, User.is_deleted == False)  # noqa: E712
        .order_by(Follow.created_at.desc())
    )
    stmt = stmt.limit(limit + 1)

    result = await db.execute(stmt)
    users = list(result.scalars().all())

    has_more = len(users) > limit
    if has_more:
        users = users[:limit]

    items = [
        UserBrief(
            id=u.id, username=u.username, display_name=u.display_name, avatar_url=u.avatar_url
        )
        for u in users
    ]

    next_cursor = encode_cursor(users[-1].created_at, users[-1].id) if has_more else None
    return PaginatedResponse(items=items, next_cursor=next_cursor, has_more=has_more)


async def block_user(db: AsyncSession, blocker_id: UUID, target_id: UUID) -> None:
    """Block a user: auto-unfollows both directions, removes mutes."""
    if str(blocker_id) == str(target_id):
        raise self_action()

    # Verify target exists
    target = await db.execute(
        select(User).where(User.id == target_id, User.is_deleted == False)  # noqa: E712
    )
    if target.scalar_one_or_none() is None:
        raise user_not_found()

    block = Block(blocker_id=blocker_id, blocked_id=target_id)
    db.add(block)

    # Auto-unfollow both directions
    await db.execute(
        delete(Follow).where(
            or_(
                and_(Follow.follower_id == blocker_id, Follow.following_id == target_id),
                and_(Follow.follower_id == target_id, Follow.following_id == blocker_id),
            )
        )
    )

    # Remove mutes both directions
    await db.execute(
        delete(Mute).where(
            or_(
                and_(Mute.muter_id == blocker_id, Mute.muted_id == target_id),
                and_(Mute.muter_id == target_id, Mute.muted_id == blocker_id),
            )
        )
    )

    await db.flush()


async def unblock_user(db: AsyncSession, blocker_id: UUID, target_id: UUID) -> None:
    """Unblock a user."""
    result = await db.execute(
        select(Block).where(Block.blocker_id == blocker_id, Block.blocked_id == target_id)
    )
    block = result.scalar_one_or_none()
    if block is None:
        return  # Silently ignore unblocking someone you haven't blocked

    await db.delete(block)
    await db.flush()


async def mute_user(db: AsyncSession, muter_id: UUID, target_id: UUID) -> None:
    """Mute a user (hidden from feed, they don't know)."""
    if str(muter_id) == str(target_id):
        raise self_action()

    mute = Mute(muter_id=muter_id, muted_id=target_id)
    db.add(mute)
    await db.flush()


async def unmute_user(db: AsyncSession, muter_id: UUID, target_id: UUID) -> None:
    """Unmute a user."""
    result = await db.execute(
        select(Mute).where(Mute.muter_id == muter_id, Mute.muted_id == target_id)
    )
    mute = result.scalar_one_or_none()
    if mute is None:
        return  # Silently ignore

    await db.delete(mute)
    await db.flush()


async def get_taste_matches(
    db: AsyncSession, user_id: UUID, limit: int
) -> list[TasteMatchResponse]:
    """Get precomputed taste matches for a user."""
    stmt = (
        select(TasteMatch, User)
        .join(
            User,
            or_(
                and_(TasteMatch.user_b_id == User.id, TasteMatch.user_a_id == user_id),
                and_(TasteMatch.user_a_id == User.id, TasteMatch.user_b_id == user_id),
            ),
        )
        .where(
            or_(TasteMatch.user_a_id == user_id, TasteMatch.user_b_id == user_id),
            User.is_deleted == False,  # noqa: E712
        )
        .order_by(TasteMatch.match_score.desc())
        .limit(limit)
    )

    result = await db.execute(stmt)
    rows = result.all()

    return [
        TasteMatchResponse(
            user=UserBrief(
                id=user.id,
                username=user.username,
                display_name=user.display_name,
                avatar_url=user.avatar_url,
            ),
            match_score=tm.match_score,
            overlapping_books_count=tm.overlapping_books_count,
        )
        for tm, user in rows
    ]
