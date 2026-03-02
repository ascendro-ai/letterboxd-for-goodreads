"""Service layer for book series."""

from __future__ import annotations

from uuid import UUID

from backend.api.errors import AppError
from backend.api.model_stubs import Series, SeriesWork, UserBook
from backend.api.schemas.series import SeriesProgressResponse, SeriesResponse, SeriesWorkItem
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload


async def get_series(
    db: AsyncSession, series_id: UUID, user_id: UUID | None = None
) -> SeriesResponse:
    """Get series detail with works in order, optionally with user reading statuses."""
    result = await db.execute(
        select(Series)
        .options(selectinload(Series.works).selectinload(SeriesWork.work))
        .where(Series.id == series_id)
    )
    series = result.scalar_one_or_none()
    if series is None:
        raise AppError(status_code=404, code="SERIES_NOT_FOUND", message="Series not found.")

    # Fetch user statuses if authenticated
    user_statuses: dict[str, str] = {}
    if user_id:
        work_ids = [sw.work_id for sw in series.works]
        if work_ids:
            ub_result = await db.execute(
                select(UserBook.work_id, UserBook.status).where(
                    UserBook.user_id == user_id, UserBook.work_id.in_(work_ids)
                )
            )
            user_statuses = {str(row[0]): row[1] for row in ub_result.all()}

    works = []
    for sw in series.works:
        work = sw.work
        authors = [a.name for a in work.authors] if work.authors else []
        works.append(
            SeriesWorkItem(
                position=float(sw.position),
                is_main_entry=sw.is_main_entry,
                work_id=work.id if hasattr(work.id, "hex") else UUID(str(work.id)),
                title=work.title,
                authors=authors,
                cover_image_url=work.cover_image_url,
                user_status=user_statuses.get(str(work.id)),
            )
        )

    return SeriesResponse(
        id=series.id if hasattr(series.id, "hex") else UUID(str(series.id)),
        name=series.name,
        description=series.description,
        total_books=series.total_books,
        is_complete=series.is_complete,
        cover_image_url=series.cover_image_url,
        works=works,
    )


async def get_series_progress(
    db: AsyncSession, series_id: UUID, user_id: UUID
) -> SeriesProgressResponse:
    """Calculate user's reading progress through a series."""
    # Verify series exists
    series_result = await db.execute(select(Series).where(Series.id == series_id))
    series = series_result.scalar_one_or_none()
    if series is None:
        raise AppError(status_code=404, code="SERIES_NOT_FOUND", message="Series not found.")

    # Count main entries
    total_result = await db.execute(
        select(func.count())
        .select_from(SeriesWork)
        .where(SeriesWork.series_id == series_id, SeriesWork.is_main_entry == True)  # noqa: E712
    )
    total_main = total_result.scalar_one()

    # Count "read" main entries
    read_result = await db.execute(
        select(func.count())
        .select_from(UserBook)
        .join(SeriesWork, SeriesWork.work_id == UserBook.work_id)
        .where(
            SeriesWork.series_id == series_id,
            SeriesWork.is_main_entry == True,  # noqa: E712
            UserBook.user_id == user_id,
            UserBook.status == "read",
        )
    )
    read_count = read_result.scalar_one()

    # Count "reading" main entries
    reading_result = await db.execute(
        select(func.count())
        .select_from(UserBook)
        .join(SeriesWork, SeriesWork.work_id == UserBook.work_id)
        .where(
            SeriesWork.series_id == series_id,
            SeriesWork.is_main_entry == True,  # noqa: E712
            UserBook.user_id == user_id,
            UserBook.status == "reading",
        )
    )
    reading_count = reading_result.scalar_one()

    progress = (read_count / total_main * 100) if total_main > 0 else 0.0

    return SeriesProgressResponse(
        series_id=series.id if hasattr(series.id, "hex") else UUID(str(series.id)),
        series_name=series.name,
        total_main_entries=total_main,
        read_count=read_count,
        reading_count=reading_count,
        progress_percent=round(progress, 1),
    )


async def get_book_series(db: AsyncSession, work_id: UUID) -> list[SeriesResponse]:
    """Get all series a book belongs to."""
    result = await db.execute(
        select(SeriesWork)
        .options(selectinload(SeriesWork.series).selectinload(Series.works))
        .where(SeriesWork.work_id == work_id)
    )
    series_works = result.scalars().all()

    responses = []
    for sw in series_works:
        series = sw.series
        works = []
        for s_work in series.works:
            work = s_work.work if hasattr(s_work, "work") and s_work.work else None
            works.append(
                SeriesWorkItem(
                    position=float(s_work.position),
                    is_main_entry=s_work.is_main_entry,
                    work_id=s_work.work_id if hasattr(s_work.work_id, "hex") else UUID(str(s_work.work_id)),
                    title=work.title if work else "Unknown",
                    authors=[a.name for a in work.authors] if work and work.authors else [],
                    cover_image_url=work.cover_image_url if work else None,
                )
            )
        responses.append(
            SeriesResponse(
                id=series.id if hasattr(series.id, "hex") else UUID(str(series.id)),
                name=series.name,
                description=series.description,
                total_books=series.total_books,
                is_complete=series.is_complete,
                cover_image_url=series.cover_image_url,
                works=works,
            )
        )

    return responses
