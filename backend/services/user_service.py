"""User profile service: view, update, search, and soft delete."""

from __future__ import annotations

from uuid import UUID

from backend.api.errors import blocked_user, user_not_found
from backend.api.model_stubs import Follow, User, UserBook
from backend.api.pagination import apply_cursor_filter, encode_cursor
from backend.api.schemas.common import PaginatedResponse
from backend.api.schemas.users import UpdateProfileRequest, UserBrief, UserProfile
from backend.services.social_service import is_blocked
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession


async def get_profile(
    db: AsyncSession,
    requesting_user_id: UUID,
    target_user_id: UUID,
) -> UserProfile:
    """Get a user profile with counts and is_following flag."""
    if str(requesting_user_id) != str(target_user_id) and await is_blocked(
        db, requesting_user_id, target_user_id
    ):
        raise blocked_user()

    result = await db.execute(
        select(User).where(User.id == target_user_id, User.is_deleted == False)  # noqa: E712
    )
    user = result.scalar_one_or_none()
    if user is None:
        raise user_not_found()

    # Count books
    books_count = (
        await db.scalar(select(func.count()).where(UserBook.user_id == target_user_id)) or 0
    )

    # Count followers
    followers_count = (
        await db.scalar(select(func.count()).where(Follow.following_id == target_user_id)) or 0
    )

    # Count following
    following_count = (
        await db.scalar(select(func.count()).where(Follow.follower_id == target_user_id)) or 0
    )

    # Check if requesting user follows target
    is_following = False
    if str(requesting_user_id) != str(target_user_id):
        follow_result = await db.execute(
            select(Follow).where(
                Follow.follower_id == requesting_user_id,
                Follow.following_id == target_user_id,
            )
        )
        is_following = follow_result.scalar_one_or_none() is not None

    return UserProfile(
        id=user.id,
        username=user.username,
        display_name=user.display_name,
        avatar_url=user.avatar_url,
        bio=user.bio,
        favorite_books=user.favorite_books or [],
        books_count=books_count,
        followers_count=followers_count,
        following_count=following_count,
        is_following=is_following,
        created_at=user.created_at,
    )


async def update_profile(
    db: AsyncSession,
    user_id: UUID,
    request: UpdateProfileRequest,
) -> UserProfile:
    """Update user profile fields."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise user_not_found()

    if request.display_name is not None:
        user.display_name = request.display_name
    if request.bio is not None:
        user.bio = request.bio
    if request.avatar_url is not None:
        user.avatar_url = request.avatar_url
    if request.favorite_books is not None:
        user.favorite_books = [str(b) for b in request.favorite_books]

    await db.flush()

    return await get_profile(db, user_id, user_id)


async def search_users(
    db: AsyncSession,
    query: str,
    cursor: str | None,
    limit: int,
) -> PaginatedResponse[UserBrief]:
    """Search users by username or display name (ILIKE for now, trigram in production)."""
    stmt = (
        select(User)
        .where(
            User.is_deleted == False,  # noqa: E712
            or_(
                User.username.ilike(f"%{query}%"),
                User.display_name.ilike(f"%{query}%"),
            ),
        )
        .order_by(User.created_at.desc(), User.id.desc())
    )
    stmt = apply_cursor_filter(stmt, User, cursor)
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


async def soft_delete_account(db: AsyncSession, user_id: UUID) -> None:
    """Soft delete: anonymize user data, mark as deleted."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise user_not_found()

    user.is_deleted = True
    user.username = f"deleted_{str(user.id)[:8]}"
    user.display_name = None
    user.bio = None
    user.avatar_url = None
    user.favorite_books = None
    await db.flush()
