"""Activity feed and notification service.

Uses fan-out-on-read: feed is built at query time by JOINing activities from
followed users. Simple and correct at our expected scale (<100K users). If
feed latency exceeds 200ms, switch to fan-out-on-write (precomputed timelines).
"""

from __future__ import annotations

from uuid import UUID

from backend.api.model_stubs import (
    Activity,
    Block,
    Follow,
    Mute,
    Notification,
    User,
    UserBook,
    Work,
)
from backend.api.pagination import apply_cursor_filter, encode_cursor
from backend.api.schemas.books import AuthorBrief, BookBrief
from backend.api.schemas.common import PaginatedResponse
from backend.api.schemas.feed import FeedItem, FeedResponse, NotificationItem
from backend.api.schemas.users import UserBrief
from backend.services.popular_service import get_popular_feed_items
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession


async def get_feed(
    db: AsyncSession,
    user_id: UUID,
    cursor: str | None,
    limit: int,
) -> FeedResponse:
    """Get activity feed. Falls back to popular feed if user has no follows."""
    follow_count = await db.scalar(select(func.count()).where(Follow.follower_id == user_id))

    if not follow_count:
        return await get_popular_feed_items(db, cursor, limit)

    following_feed = await _get_following_feed(db, user_id, cursor, limit)

    # If the user follows people but the feed is empty (e.g. new follows, no
    # activity yet), mix in popular items
    if not following_feed.items and cursor is None:
        popular = await get_popular_feed_items(db, cursor, limit)
        return FeedResponse(
            items=popular.items,
            next_cursor=popular.next_cursor,
            has_more=popular.has_more,
            feed_type="mixed",
        )

    return following_feed


async def _get_following_feed(
    db: AsyncSession,
    user_id: UUID,
    cursor: str | None,
    limit: int,
) -> FeedResponse:
    """Fan-out-on-read: activities from followed users, excluding muted/blocked."""
    following_ids = select(Follow.following_id).where(Follow.follower_id == user_id)
    # Exclude both directions of blocks -- if either party blocked, hide from feed
    blocked_ids = select(Block.blocked_id).where(Block.blocker_id == user_id)
    blocked_by_ids = select(Block.blocker_id).where(Block.blocked_id == user_id)
    muted_ids = select(Mute.muted_id).where(Mute.muter_id == user_id)

    stmt = (
        select(Activity)
        .where(
            Activity.user_id.in_(following_ids),
            Activity.user_id.notin_(blocked_ids),
            Activity.user_id.notin_(blocked_by_ids),
            Activity.user_id.notin_(muted_ids),
            Activity.activity_type.in_(["finished_book", "started_book"]),
        )
        .order_by(Activity.created_at.desc(), Activity.id.desc())
    )
    stmt = apply_cursor_filter(stmt, Activity, cursor)
    stmt = stmt.limit(limit + 1)

    result = await db.execute(stmt)
    activities = list(result.scalars().all())

    has_more = len(activities) > limit
    if has_more:
        activities = activities[:limit]

    feed = await _activities_to_feed(db, activities, has_more)
    return FeedResponse(
        items=feed.items,
        next_cursor=feed.next_cursor,
        has_more=feed.has_more,
        feed_type="following",
    )


async def _activities_to_feed(
    db: AsyncSession,
    activities: list[Activity],
    has_more: bool,
) -> PaginatedResponse[FeedItem]:
    """Convert Activity objects to FeedItem responses with related data."""
    if not activities:
        return PaginatedResponse(items=[], next_cursor=None, has_more=False)

    # Batch load users, user_books, works
    user_ids = list({a.user_id for a in activities})
    target_ids = list({a.target_id for a in activities})

    users_result = await db.execute(select(User).where(User.id.in_(user_ids)))
    users_map = {u.id: u for u in users_result.scalars().all()}

    ub_result = await db.execute(select(UserBook).where(UserBook.id.in_(target_ids)))
    ub_map = {ub.id: ub for ub in ub_result.scalars().all()}

    work_ids = list({ub.work_id for ub in ub_map.values()})
    if work_ids:
        works_result = await db.execute(select(Work).where(Work.id.in_(work_ids)))
        works_map = {w.id: w for w in works_result.scalars().all()}
    else:
        works_map = {}

    items = []
    for activity in activities:
        user = users_map.get(activity.user_id)
        user_book = ub_map.get(activity.target_id)
        work = works_map.get(user_book.work_id) if user_book else None

        if not user or not user_book or not work:
            continue

        items.append(
            FeedItem(
                id=activity.id,
                user=UserBrief(
                    id=user.id,
                    username=user.username,
                    display_name=user.display_name,
                    avatar_url=user.avatar_url,
                ),
                activity_type=activity.activity_type,
                book=BookBrief(
                    id=work.id,
                    title=work.title,
                    authors=[AuthorBrief(id=a.id, name=a.name) for a in (work.authors or [])],
                    cover_image_url=work.cover_image_url,
                    average_rating=work.average_rating,
                    ratings_count=work.ratings_count,
                ),
                rating=user_book.rating,
                review_text=user_book.review_text,
                has_spoilers=user_book.has_spoilers,
                created_at=activity.created_at,
            )
        )

    next_cursor = encode_cursor(activities[-1].created_at, activities[-1].id) if has_more else None

    return PaginatedResponse(items=items, next_cursor=next_cursor, has_more=has_more)


async def get_notifications(
    db: AsyncSession,
    user_id: UUID,
    cursor: str | None,
    limit: int,
) -> PaginatedResponse[NotificationItem]:
    """Get user's notifications (paginated)."""
    stmt = (
        select(Notification)
        .where(Notification.user_id == user_id)
        .order_by(Notification.created_at.desc(), Notification.id.desc())
    )
    stmt = apply_cursor_filter(stmt, Notification, cursor)
    stmt = stmt.limit(limit + 1)

    result = await db.execute(stmt)
    notifications = list(result.scalars().all())

    has_more = len(notifications) > limit
    if has_more:
        notifications = notifications[:limit]

    # Load actors
    actor_ids = list({n.actor_id for n in notifications if n.actor_id})
    if actor_ids:
        actors_result = await db.execute(select(User).where(User.id.in_(actor_ids)))
        actors_map = {u.id: u for u in actors_result.scalars().all()}
    else:
        actors_map = {}

    items = []
    for n in notifications:
        actor = actors_map.get(n.actor_id) if n.actor_id else None
        items.append(
            NotificationItem(
                id=n.id,
                type=n.type,
                actor=UserBrief(
                    id=actor.id,
                    username=actor.username,
                    display_name=actor.display_name,
                    avatar_url=actor.avatar_url,
                )
                if actor
                else None,
                data=n.data,
                is_read=n.is_read,
                created_at=n.created_at,
            )
        )

    next_cursor = (
        encode_cursor(notifications[-1].created_at, notifications[-1].id) if has_more else None
    )

    return PaginatedResponse(items=items, next_cursor=next_cursor, has_more=has_more)


async def mark_notifications_read(
    db: AsyncSession, user_id: UUID, notification_ids: list[UUID]
) -> None:
    """Bulk mark notifications as read."""
    await db.execute(
        update(Notification)
        .where(
            Notification.id.in_(notification_ids),
            Notification.user_id == user_id,
        )
        .values(is_read=True)
    )
    await db.flush()
