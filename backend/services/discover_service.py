from __future__ import annotations

from uuid import UUID

from backend.api.model_stubs import (
    Block,
    Follow,
    TasteMatch,
    User,
    UserContactHash,
)
from backend.api.schemas.discovery import DiscoverUserResponse
from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession


async def store_user_hashes(
    db: AsyncSession,
    user_id: UUID,
    email: str,
    phone: str | None = None,
) -> None:
    """Store hashed contact info for a user during signup.

    The backend hashes the user's own email and phone server-side so they
    can be discovered by other users who upload contact hashes.
    """
    import hashlib

    hashes_to_store: list[tuple[str, str]] = []

    # Hash the user's email (normalize: lowercase, strip whitespace)
    normalized_email = email.strip().lower()
    email_hash = hashlib.sha256(normalized_email.encode("utf-8")).hexdigest()
    hashes_to_store.append((email_hash, "email"))

    # Hash the user's phone if provided (normalize: strip non-digits)
    if phone:
        normalized_phone = "".join(c for c in phone if c.isdigit())
        if normalized_phone:
            phone_hash = hashlib.sha256(normalized_phone.encode("utf-8")).hexdigest()
            hashes_to_store.append((phone_hash, "phone"))

    for hash_value, hash_type in hashes_to_store:
        existing = await db.execute(
            select(UserContactHash).where(
                UserContactHash.hash == hash_value,
                UserContactHash.hash_type == hash_type,
            )
        )
        if existing.scalar_one_or_none() is None:
            contact_hash = UserContactHash(
                user_id=user_id,
                hash=hash_value,
                hash_type=hash_type,
            )
            db.add(contact_hash)

    await db.flush()


async def find_contacts(
    db: AsyncSession,
    current_user_id: UUID,
    hashes: list[str],
) -> list[DiscoverUserResponse]:
    """Find registered users whose contact info matches the uploaded hashes.

    The client hashes contacts locally (email/phone -> SHA-256 hex) and uploads
    the hashes. We match against stored user_contact_hashes to find users.
    Excludes the current user and blocked users.
    """
    if not hashes:
        return []

    # Subquery: users blocked by or blocking the current user
    blocked_ids = select(Block.blocked_id).where(Block.blocker_id == current_user_id)
    blocked_by_ids = select(Block.blocker_id).where(Block.blocked_id == current_user_id)

    # Find user IDs that match any of the uploaded hashes
    stmt = (
        select(
            User.id,
            User.username,
            User.display_name,
            User.avatar_url,
        )
        .join(UserContactHash, UserContactHash.user_id == User.id)
        .where(
            UserContactHash.hash.in_(hashes),
            User.id != current_user_id,
            User.is_deleted == False,  # noqa: E712
            User.id.notin_(blocked_ids),
            User.id.notin_(blocked_by_ids),
        )
        .group_by(User.id, User.username, User.display_name, User.avatar_url)
    )

    result = await db.execute(stmt)
    rows = result.all()

    if not rows:
        return []

    # Fetch taste match scores for matched users
    user_ids = [row.id for row in rows]
    taste_stmt = select(TasteMatch).where(
        or_(
            and_(
                TasteMatch.user_a_id == current_user_id,
                TasteMatch.user_b_id.in_(user_ids),
            ),
            and_(
                TasteMatch.user_b_id == current_user_id,
                TasteMatch.user_a_id.in_(user_ids),
            ),
        )
    )
    taste_result = await db.execute(taste_stmt)
    taste_matches = taste_result.scalars().all()

    # Build a map of user_id -> match_score
    score_map: dict[str, float] = {}
    for tm in taste_matches:
        if str(tm.user_a_id) == str(current_user_id):
            other_id = str(tm.user_b_id)
        else:
            other_id = str(tm.user_a_id)
        score_map[other_id] = tm.match_score

    return [
        DiscoverUserResponse(
            id=row.id,
            username=row.username,
            display_name=row.display_name,
            avatar_url=row.avatar_url,
            taste_match_score=score_map.get(str(row.id)),
        )
        for row in rows
    ]


async def get_taste_suggestions(
    db: AsyncSession,
    user_id: UUID,
    limit: int = 20,
) -> list[DiscoverUserResponse]:
    """Get users with the highest taste match scores who the current user
    is not yet following. Excludes blocked and muted users.
    """
    # Subquery: users already followed
    following_ids = select(Follow.following_id).where(Follow.follower_id == user_id)

    # Subquery: blocked users (both directions)
    blocked_ids = select(Block.blocked_id).where(Block.blocker_id == user_id)
    blocked_by_ids = select(Block.blocker_id).where(Block.blocked_id == user_id)

    # Query taste matches where the current user is either side
    stmt = (
        select(
            User.id,
            User.username,
            User.display_name,
            User.avatar_url,
            TasteMatch.match_score,
        )
        .join(
            TasteMatch,
            or_(
                and_(
                    TasteMatch.user_b_id == User.id,
                    TasteMatch.user_a_id == user_id,
                ),
                and_(
                    TasteMatch.user_a_id == User.id,
                    TasteMatch.user_b_id == user_id,
                ),
            ),
        )
        .where(
            User.id != user_id,
            User.is_deleted == False,  # noqa: E712
            User.id.notin_(following_ids),
            User.id.notin_(blocked_ids),
            User.id.notin_(blocked_by_ids),
        )
        .order_by(TasteMatch.match_score.desc())
        .limit(limit)
    )

    result = await db.execute(stmt)
    rows = result.all()

    return [
        DiscoverUserResponse(
            id=row.id,
            username=row.username,
            display_name=row.display_name,
            avatar_url=row.avatar_url,
            taste_match_score=row.match_score,
        )
        for row in rows
    ]


async def get_popular_users(
    db: AsyncSession,
    user_id: UUID,
    limit: int = 20,
) -> list[DiscoverUserResponse]:
    """Get popular users ordered by follower count, excluding the current
    user, blocked users, and already-followed users.
    """
    # Subquery: users already followed
    following_ids = select(Follow.following_id).where(Follow.follower_id == user_id)

    # Subquery: blocked users (both directions)
    blocked_ids = select(Block.blocked_id).where(Block.blocker_id == user_id)
    blocked_by_ids = select(Block.blocker_id).where(Block.blocked_id == user_id)

    # Count followers per user
    follower_count = (
        select(
            Follow.following_id.label("user_id"),
            func.count().label("follower_count"),
        )
        .group_by(Follow.following_id)
        .subquery()
    )

    stmt = (
        select(
            User.id,
            User.username,
            User.display_name,
            User.avatar_url,
            follower_count.c.follower_count,
        )
        .outerjoin(follower_count, follower_count.c.user_id == User.id)
        .where(
            User.id != user_id,
            User.is_deleted == False,  # noqa: E712
            User.id.notin_(following_ids),
            User.id.notin_(blocked_ids),
            User.id.notin_(blocked_by_ids),
        )
        .order_by(follower_count.c.follower_count.desc().nullslast())
        .limit(limit)
    )

    result = await db.execute(stmt)
    rows = result.all()

    return [
        DiscoverUserResponse(
            id=row.id,
            username=row.username,
            display_name=row.display_name,
            avatar_url=row.avatar_url,
            taste_match_score=None,
        )
        for row in rows
    ]
