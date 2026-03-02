from __future__ import annotations

from datetime import datetime, timezone
from uuid import UUID

from backend.api.errors import blocked_user, user_not_found
from backend.api.model_stubs import (
    Activity,
    Block,
    ExportRequest,
    Follow,
    InviteCode,
    Mute,
    Notification,
    Shelf,
    ShelfBook,
    User,
    UserBook,
    UserContactHash,
)
from backend.api.pagination import apply_cursor_filter, encode_cursor
from backend.api.schemas.common import PaginatedResponse
from backend.api.schemas.users import UpdateProfileRequest, UserBrief, UserProfile
from backend.services.social_service import is_blocked
from sqlalchemy import delete, func, or_, select, update
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

    if request.username is not None:
        user.username = request.username
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
    """Comprehensive GDPR-compliant account deletion with data anonymization.

    Steps performed:
      1. Mark user as deleted with timestamp
      2. Anonymize profile (username, display_name, bio, avatar, favorites)
      3. Delete all contact hashes (friend discovery)
      4. Invalidate all invite codes created by user
      5. Delete all follows (both directions)
      6. Delete all blocks and mutes (both directions)
      7. Keep reviews and ratings (they persist as "Deleted User")
      8. Keep user_books records (ratings/reviews stay)
      9. Delete all shelves and shelf_books
     10. Delete all pending export requests
     11. Delete all activities from feed
     12. Clear all notification records
    """
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise user_not_found()

    now = datetime.now(timezone.utc)

    # --- Step 1: Mark as deleted ---
    user.is_deleted = True
    user.deleted_at = now

    # --- Step 2: Anonymize profile ---
    user.username = f"deleted_{str(user_id)[:8]}"
    user.display_name = "Deleted User"
    user.bio = None
    user.avatar_url = None
    user.favorite_books = []

    # --- Step 3: Delete contact hashes (friend discovery) ---
    await db.execute(delete(UserContactHash).where(UserContactHash.user_id == user_id))

    # --- Step 4: Invalidate invite codes ---
    await db.execute(
        update(InviteCode).where(InviteCode.created_by_user_id == user_id).values(expires_at=now)
    )

    # --- Step 5: Delete all follows (both directions) ---
    await db.execute(
        delete(Follow).where(or_(Follow.follower_id == user_id, Follow.following_id == user_id))
    )

    # --- Step 6: Delete all blocks and mutes (both directions) ---
    await db.execute(
        delete(Block).where(or_(Block.blocker_id == user_id, Block.blocked_id == user_id))
    )
    await db.execute(delete(Mute).where(or_(Mute.muter_id == user_id, Mute.muted_id == user_id)))

    # --- Steps 7-8: Keep reviews and user_books (no action needed) ---

    # --- Step 9: Delete all shelves and shelf_books ---
    shelf_ids_result = await db.execute(select(Shelf.id).where(Shelf.user_id == user_id))
    shelf_ids = [row[0] for row in shelf_ids_result.all()]

    if shelf_ids:
        await db.execute(delete(ShelfBook).where(ShelfBook.shelf_id.in_(shelf_ids)))
        await db.execute(delete(Shelf).where(Shelf.user_id == user_id))

    # --- Step 10: Delete pending export requests ---
    await db.execute(delete(ExportRequest).where(ExportRequest.user_id == user_id))

    # --- Step 11: Delete all activities from feed ---
    await db.execute(delete(Activity).where(Activity.user_id == user_id))

    # --- Step 12: Clear notification records ---
    await db.execute(delete(Notification).where(Notification.user_id == user_id))
    await db.execute(delete(Notification).where(Notification.actor_id == user_id))

    await db.flush()
