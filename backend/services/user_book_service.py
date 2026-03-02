"""Reading log service: log books, rate, review, update status.

Business rules:
- Ratings require a review (encourages thoughtful engagement). Imported books
  are exempt since they were already rated on another platform.
- Only "reading" and "read" status changes create Activity entries. "Want to
  read" and "did not finish" are silent -- they'd clutter feeds without being
  interesting to followers.
"""

from __future__ import annotations

from decimal import Decimal
from uuid import UUID

from backend.api.errors import (
    already_logged,
    blocked_user,
    book_not_found,
    review_required,
    user_book_not_found,
)
from backend.api.model_stubs import Activity, ShelfBook, UserBook, Work
from backend.api.pagination import apply_cursor_filter, encode_cursor
from backend.api.schemas.books import AuthorBrief, BookBrief
from backend.api.schemas.common import PaginatedResponse
from backend.api.schemas.user_books import LogBookRequest, UpdateBookRequest, UserBookResponse
from backend.services.social_service import is_blocked
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession


async def log_book(
    db: AsyncSession,
    user_id: UUID,
    request: LogBookRequest,
) -> UserBookResponse:
    """Log a book: validate, create UserBook, create Activity, update stats."""
    # Verify work exists
    work_result = await db.execute(select(Work).where(Work.id == request.work_id))
    work = work_result.scalar_one_or_none()
    if work is None:
        raise book_not_found()

    # Check for duplicate
    existing = await db.execute(
        select(UserBook).where(UserBook.user_id == user_id, UserBook.work_id == request.work_id)
    )
    if existing.scalar_one_or_none() is not None:
        raise already_logged()

    # Enforce review-required rule (new ratings only, imports exempt)
    if request.rating is not None and not request.review_text:
        raise review_required()

    user_book = UserBook(
        user_id=user_id,
        work_id=request.work_id,
        status=request.status,
        rating=request.rating,
        review_text=request.review_text,
        has_spoilers=request.has_spoilers,
        started_at=request.started_at,
        finished_at=request.finished_at,
        is_private=request.is_private,
    )
    db.add(user_book)
    await db.flush()

    # Create activity (private books don't generate feed entries)
    if request.status in ("read", "reading") and not request.is_private:
        activity_type = "finished_book" if request.status == "read" else "started_book"
        activity = Activity(
            user_id=user_id,
            activity_type=activity_type,
            target_id=user_book.id,
        )
        db.add(activity)

    # Update work aggregate stats if rated
    if request.rating is not None:
        await _update_work_rating(db, request.work_id)

    await db.flush()

    return _to_response(user_book, work)


async def update_book(
    db: AsyncSession,
    user_id: UUID,
    user_book_id: UUID,
    request: UpdateBookRequest,
) -> UserBookResponse:
    """Update a logged book's status, rating, or review."""
    result = await db.execute(
        select(UserBook).where(UserBook.id == user_book_id, UserBook.user_id == user_id)
    )
    user_book = result.scalar_one_or_none()
    if user_book is None:
        raise user_book_not_found()

    old_status = user_book.status

    if request.status is not None:
        user_book.status = request.status
    if request.rating is not None:
        # Enforce review-required for non-imported books
        review = request.review_text
        new_review = review if review is not None else user_book.review_text
        if not new_review and not user_book.is_imported:
            raise review_required()
        user_book.rating = request.rating
    if request.review_text is not None:
        user_book.review_text = request.review_text
    if request.has_spoilers is not None:
        user_book.has_spoilers = request.has_spoilers
    if request.started_at is not None:
        user_book.started_at = request.started_at
    if request.finished_at is not None:
        user_book.finished_at = request.finished_at
    if request.is_private is not None:
        user_book.is_private = request.is_private

    # Create activity on status change to read/reading (private books are silent)
    new_status = user_book.status
    if new_status != old_status and new_status in ("read", "reading") and not user_book.is_private:
        activity_type = "finished_book" if new_status == "read" else "started_book"
        activity = Activity(
            user_id=user_id,
            activity_type=activity_type,
            target_id=user_book.id,
        )
        db.add(activity)

    if request.rating is not None:
        await _update_work_rating(db, user_book.work_id)

    await db.flush()
    await db.refresh(user_book)

    work_result = await db.execute(select(Work).where(Work.id == user_book.work_id))
    work = work_result.scalar_one_or_none()

    return _to_response(user_book, work)


async def delete_book(
    db: AsyncSession,
    user_id: UUID,
    user_book_id: UUID,
) -> None:
    """Remove a book from user's library and cascade shelf_books."""
    result = await db.execute(
        select(UserBook).where(UserBook.id == user_book_id, UserBook.user_id == user_id)
    )
    user_book = result.scalar_one_or_none()
    if user_book is None:
        raise user_book_not_found()

    work_id = user_book.work_id

    # Remove from any shelves
    await db.execute(ShelfBook.__table__.delete().where(ShelfBook.user_book_id == user_book_id))

    await db.delete(user_book)
    await _update_work_rating(db, work_id)
    await db.flush()


async def list_user_books(
    db: AsyncSession,
    requesting_user_id: UUID,
    target_user_id: UUID,
    status_filter: str | None,
    cursor: str | None,
    limit: int,
) -> PaginatedResponse[UserBookResponse]:
    """List a user's books. Checks blocks if viewing another user."""
    if str(requesting_user_id) != str(target_user_id) and await is_blocked(
        db, requesting_user_id, target_user_id
    ):
        raise blocked_user()

    stmt = select(UserBook).where(UserBook.user_id == target_user_id)

    # Hide private books when viewing another user's library
    if str(requesting_user_id) != str(target_user_id):
        stmt = stmt.where(UserBook.is_private == False)  # noqa: E712

    if status_filter:
        stmt = stmt.where(UserBook.status == status_filter)
    stmt = stmt.order_by(UserBook.created_at.desc(), UserBook.id.desc())
    stmt = apply_cursor_filter(stmt, UserBook, cursor)
    stmt = stmt.limit(limit + 1)

    result = await db.execute(stmt)
    user_books = list(result.scalars().all())

    has_more = len(user_books) > limit
    if has_more:
        user_books = user_books[:limit]

    # Batch load works
    if user_books:
        work_ids = [ub.work_id for ub in user_books]
        works_result = await db.execute(select(Work).where(Work.id.in_(work_ids)))
        works_map = {w.id: w for w in works_result.scalars().all()}
    else:
        works_map = {}

    items = [_to_response(ub, works_map.get(ub.work_id)) for ub in user_books]
    next_cursor = encode_cursor(user_books[-1].created_at, user_books[-1].id) if has_more else None

    return PaginatedResponse(items=items, next_cursor=next_cursor, has_more=has_more)


async def _update_work_rating(db: AsyncSession, work_id: UUID) -> None:
    """Recalculate average_rating and ratings_count for a work.

    Called after every rating change. Uses SQL avg/count for correctness.
    round(, 2) matches the Numeric(3,2) column precision.
    """
    result = await db.execute(
        select(
            func.count().label("cnt"),
            func.avg(UserBook.rating).label("avg"),
        ).where(
            UserBook.work_id == work_id,
            UserBook.rating.isnot(None),
        )
    )
    row = result.one()
    work_result = await db.execute(select(Work).where(Work.id == work_id))
    work = work_result.scalar_one_or_none()
    if work:
        work.ratings_count = row.cnt or 0
        work.average_rating = Decimal(str(round(float(row.avg or 0), 2))) if row.avg else None


def _to_response(user_book: UserBook, work: Work | None) -> UserBookResponse:
    """Convert a UserBook + Work to a response schema."""
    book_brief = None
    if work:
        book_brief = BookBrief(
            id=work.id,
            title=work.title,
            authors=[AuthorBrief(id=a.id, name=a.name) for a in (work.authors or [])],
            cover_image_url=work.cover_image_url,
            average_rating=work.average_rating,
            ratings_count=work.ratings_count,
        )

    return UserBookResponse(
        id=user_book.id,
        work_id=user_book.work_id,
        status=user_book.status,
        rating=user_book.rating,
        review_text=user_book.review_text,
        has_spoilers=user_book.has_spoilers,
        started_at=user_book.started_at,
        finished_at=user_book.finished_at,
        is_imported=user_book.is_imported,
        is_private=user_book.is_private,
        created_at=user_book.created_at,
        updated_at=user_book.updated_at,
        book=book_brief,
    )
