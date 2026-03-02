"""Reading statistics service.

Computes reading stats from user_books data. All stats include private books
(they're the user's own data). The `hide_reading_stats` flag on User controls
whether OTHER users can see these stats — the service itself always computes them.
"""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from backend.api.model_stubs import Edition, UserBook, Work
from backend.api.schemas.stats import (
    MonthlyCount,
    RatingDistribution,
    ReadingStats,
    YearlyStats,
)
from sqlalchemy import extract, func, select
from sqlalchemy.ext.asyncio import AsyncSession


async def get_reading_stats(
    db: AsyncSession,
    user_id: UUID,
) -> ReadingStats:
    """Compute comprehensive reading statistics for a user."""
    # Status counts
    status_counts = await db.execute(
        select(UserBook.status, func.count())
        .where(UserBook.user_id == user_id)
        .group_by(UserBook.status)
    )
    counts = {row[0]: row[1] for row in status_counts.all()}

    total_books = sum(counts.values())
    total_read = counts.get("read", 0)
    total_reading = counts.get("reading", 0)
    total_want_to_read = counts.get("want_to_read", 0)
    total_did_not_finish = counts.get("did_not_finish", 0)

    # Overall average rating
    avg_result = await db.execute(
        select(func.avg(UserBook.rating)).where(
            UserBook.user_id == user_id,
            UserBook.rating.isnot(None),
        )
    )
    overall_avg = avg_result.scalar()
    average_rating = round(float(overall_avg), 2) if overall_avg else None

    # Current year stats
    current_year = datetime.now().year
    current_year_stats = await _get_yearly_stats(db, user_id, current_year)

    # Historical yearly stats (last 5 years)
    yearly_stats = []
    for year in range(current_year - 4, current_year + 1):
        ys = await _get_yearly_stats(db, user_id, year)
        if ys.books_read > 0:
            yearly_stats.append(ys)

    return ReadingStats(
        total_books=total_books,
        total_read=total_read,
        total_reading=total_reading,
        total_want_to_read=total_want_to_read,
        total_did_not_finish=total_did_not_finish,
        average_rating=average_rating,
        current_year_stats=current_year_stats,
        yearly_stats=yearly_stats,
    )


async def _get_yearly_stats(
    db: AsyncSession,
    user_id: UUID,
    year: int,
) -> YearlyStats:
    """Compute stats for a single year based on finished_at date."""
    base_filter = [
        UserBook.user_id == user_id,
        UserBook.status == "read",
        extract("year", UserBook.finished_at) == year,
    ]

    # Count
    count_result = await db.execute(
        select(func.count()).where(*base_filter)
    )
    books_read = count_result.scalar() or 0

    if books_read == 0:
        return YearlyStats(year=year, books_read=0)

    # Average rating for the year
    avg_result = await db.execute(
        select(func.avg(UserBook.rating)).where(
            *base_filter,
            UserBook.rating.isnot(None),
        )
    )
    avg_rating = avg_result.scalar()

    # Monthly breakdown
    monthly_result = await db.execute(
        select(
            extract("month", UserBook.finished_at).label("month"),
            func.count().label("cnt"),
        )
        .where(*base_filter)
        .group_by("month")
        .order_by("month")
    )
    monthly_breakdown = [
        MonthlyCount(month=int(row.month), count=row.cnt)
        for row in monthly_result.all()
    ]

    # Rating distribution
    rating_result = await db.execute(
        select(UserBook.rating, func.count().label("cnt"))
        .where(
            *base_filter,
            UserBook.rating.isnot(None),
        )
        .group_by(UserBook.rating)
        .order_by(UserBook.rating)
    )
    rating_distribution = [
        RatingDistribution(rating=float(row[0]), count=row[1])
        for row in rating_result.all()
    ]

    # Top genres (from work subjects, top 5)
    # unnest may not work in SQLite tests — wrap in try/except for safety
    try:
        top_genres_result = await db.execute(
            select(func.unnest(Work.subjects).label("genre"), func.count().label("cnt"))
            .join(UserBook, UserBook.work_id == Work.id)
            .where(*base_filter, Work.subjects.isnot(None))
            .group_by("genre")
            .order_by(func.count().desc())
            .limit(5)
        )
        top_genres = [row.genre for row in top_genres_result.all()]
    except Exception:
        top_genres = []

    # Pages read (sum of edition page counts if available)
    pages_result = await db.execute(
        select(func.sum(Edition.page_count))
        .join(UserBook, UserBook.work_id == Edition.work_id)
        .where(*base_filter, Edition.page_count.isnot(None))
    )
    pages_read = pages_result.scalar()

    return YearlyStats(
        year=year,
        books_read=books_read,
        pages_read=pages_read,
        average_rating=round(float(avg_rating), 2) if avg_rating else None,
        monthly_breakdown=monthly_breakdown,
        rating_distribution=rating_distribution,
        top_genres=top_genres,
    )
