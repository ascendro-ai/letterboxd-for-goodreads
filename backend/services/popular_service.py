from __future__ import annotations

from datetime import datetime, timedelta, timezone

from backend.api.model_stubs import Activity, User, UserBook, Work
from backend.api.pagination import apply_cursor_filter, encode_cursor
from backend.api.schemas.books import AuthorBrief, BookBrief
from backend.api.schemas.feed import FeedItem, FeedResponse
from backend.api.schemas.users import UserBrief
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession


async def get_popular_books_this_week(
    db: AsyncSession,
    limit: int = 20,
) -> list[BookBrief]:
    """Return books with the most 'read' activity in the last 7 days."""
    one_week_ago = datetime.now(timezone.utc) - timedelta(days=7)

    stmt = (
        select(
            UserBook.work_id,
            func.count(UserBook.id).label("activity_count"),
        )
        .where(
            UserBook.status == "read",
            UserBook.created_at > one_week_ago,
        )
        .group_by(UserBook.work_id)
        .order_by(func.count(UserBook.id).desc())
        .limit(limit)
    )

    result = await db.execute(stmt)
    rows = result.all()

    if not rows:
        return []

    work_ids = [row.work_id for row in rows]
    works_result = await db.execute(select(Work).where(Work.id.in_(work_ids)))
    works_map = {w.id: w for w in works_result.scalars().all()}

    books: list[BookBrief] = []
    for row in rows:
        work = works_map.get(row.work_id)
        if not work:
            continue
        books.append(
            BookBrief(
                id=work.id,
                title=work.title,
                authors=[AuthorBrief(id=a.id, name=a.name) for a in (work.authors or [])],
                cover_image_url=work.cover_image_url,
                average_rating=work.average_rating,
                ratings_count=work.ratings_count,
            )
        )

    return books


async def get_trending_books(
    db: AsyncSession,
    hours: int = 48,
    limit: int = 20,
) -> list[BookBrief]:
    """Return books with the most activity in the last N hours."""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)

    stmt = (
        select(
            Activity.target_id,
            func.count(Activity.id).label("activity_count"),
        )
        .where(
            Activity.activity_type == "finished_book",
            Activity.created_at > cutoff,
        )
        .group_by(Activity.target_id)
        .order_by(func.count(Activity.id).desc())
        .limit(limit)
    )

    result = await db.execute(stmt)
    rows = result.all()

    if not rows:
        return []

    ub_ids = [row.target_id for row in rows]
    ub_result = await db.execute(select(UserBook).where(UserBook.id.in_(ub_ids)))
    ub_map = {ub.id: ub for ub in ub_result.scalars().all()}

    work_ids = list({ub.work_id for ub in ub_map.values()})
    works_result = await db.execute(select(Work).where(Work.id.in_(work_ids)))
    works_map = {w.id: w for w in works_result.scalars().all()}

    seen_work_ids: set = set()
    books: list[BookBrief] = []
    for row in rows:
        ub = ub_map.get(row.target_id)
        if not ub:
            continue
        work = works_map.get(ub.work_id)
        if not work or work.id in seen_work_ids:
            continue
        seen_work_ids.add(work.id)
        books.append(
            BookBrief(
                id=work.id,
                title=work.title,
                authors=[AuthorBrief(id=a.id, name=a.name) for a in (work.authors or [])],
                cover_image_url=work.cover_image_url,
                average_rating=work.average_rating,
                ratings_count=work.ratings_count,
            )
        )

    return books


async def get_popular_feed_items(
    db: AsyncSession,
    cursor: str | None,
    limit: int,
) -> FeedResponse:
    """Cold start feed: recent finished_book activities globally, only those with ratings."""
    stmt = (
        select(Activity)
        .where(Activity.activity_type == "finished_book")
        .order_by(Activity.created_at.desc(), Activity.id.desc())
    )
    stmt = apply_cursor_filter(stmt, Activity, cursor)
    stmt = stmt.limit(limit + 1)

    result = await db.execute(stmt)
    activities = list(result.scalars().all())

    has_more = len(activities) > limit
    if has_more:
        activities = activities[:limit]

    if not activities:
        return FeedResponse(items=[], next_cursor=None, has_more=False, feed_type="popular")

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

    items: list[FeedItem] = []
    for activity in activities:
        user = users_map.get(activity.user_id)
        user_book = ub_map.get(activity.target_id)
        work = works_map.get(user_book.work_id) if user_book else None

        if not user or not user_book or not work:
            continue

        # Only include activities with ratings for the popular feed
        if user_book.rating is None:
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

    return FeedResponse(
        items=items,
        next_cursor=next_cursor,
        has_more=has_more,
        feed_type="popular",
    )
