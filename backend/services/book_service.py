from __future__ import annotations

from uuid import UUID

import httpx
from backend.api.config import get_settings
from backend.api.errors import book_not_found
from backend.api.model_stubs import (
    Block,
    Edition,
    UserBook,
    Work,
)
from backend.api.pagination import apply_cursor_filter, encode_cursor
from backend.api.schemas.books import AuthorBrief, BookDetail, BookSearchResult
from backend.api.schemas.common import PaginatedResponse
from backend.api.schemas.user_books import UserBookResponse
from backend.services.affiliate_service import generate_bookshop_url, get_best_isbn_for_work
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession


async def search_books(
    db: AsyncSession,
    query: str,
    cursor: str | None,
    limit: int,
) -> PaginatedResponse[BookSearchResult]:
    """Search books by title using ILIKE (Postgres tsvector/trigram in production)."""
    stmt = (
        select(Work)
        .where(Work.title.ilike(f"%{query}%"))
        .order_by(Work.ratings_count.desc(), Work.created_at.desc(), Work.id.desc())
    )
    stmt = apply_cursor_filter(stmt, Work, cursor)
    stmt = stmt.limit(limit + 1)

    result = await db.execute(stmt)
    works = list(result.scalars().all())

    has_more = len(works) > limit
    if has_more:
        works = works[:limit]

    items = [
        BookSearchResult(
            id=w.id,
            title=w.title,
            authors=[AuthorBrief(id=a.id, name=a.name) for a in (w.authors or [])],
            cover_image_url=w.cover_image_url,
            first_published_year=w.first_published_year,
        )
        for w in works
    ]

    next_cursor = encode_cursor(works[-1].created_at, works[-1].id) if has_more else None

    return PaginatedResponse(items=items, next_cursor=next_cursor, has_more=has_more)


async def get_book_detail(db: AsyncSession, work_id: UUID) -> BookDetail:
    """Get full book detail with authors and edition count."""
    result = await db.execute(select(Work).where(Work.id == work_id))
    work = result.scalar_one_or_none()
    if work is None:
        raise book_not_found()

    # Count editions
    editions_count_result = await db.execute(
        select(func.count()).select_from(Edition).where(Edition.work_id == work_id)
    )
    editions_count = editions_count_result.scalar() or 0

    settings = get_settings()
    isbn = await get_best_isbn_for_work(db, work_id)
    bookshop_url = generate_bookshop_url(isbn, work.title, settings.bookshop_affiliate_id)

    return BookDetail(
        id=work.id,
        title=work.title,
        original_title=work.original_title,
        description=work.description,
        first_published_year=work.first_published_year,
        authors=[AuthorBrief(id=a.id, name=a.name) for a in (work.authors or [])],
        subjects=work.subjects or [],
        cover_image_url=work.cover_image_url,
        average_rating=work.average_rating,
        ratings_count=work.ratings_count,
        editions_count=editions_count,
        bookshop_url=bookshop_url,
    )


async def lookup_by_isbn(db: AsyncSession, isbn: str) -> BookDetail:
    """Look up a book by ISBN. Falls back to Open Library API if not found locally."""
    isbn_clean = isbn.replace("-", "").strip()

    # Try local DB first
    result = await db.execute(
        select(Edition).where((Edition.isbn_13 == isbn_clean) | (Edition.isbn_10 == isbn_clean))
    )
    edition = result.scalar_one_or_none()

    if edition is not None:
        return await get_book_detail(db, edition.work_id)

    # Fallback: live Open Library API
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"https://openlibrary.org/isbn/{isbn_clean}.json",
            follow_redirects=True,
            timeout=10.0,
        )
        if resp.status_code != 200:
            raise book_not_found()

        ol_data = resp.json()
        # Try to resolve work from OL work key
        work_keys = ol_data.get("works", [])
        if work_keys:
            ol_work_id = work_keys[0]["key"].split("/")[-1]
            work_result = await db.execute(
                select(Work).where(Work.open_library_work_id == ol_work_id)
            )
            work = work_result.scalar_one_or_none()
            if work is not None:
                return await get_book_detail(db, work.id)

    raise book_not_found()


async def get_book_reviews(
    db: AsyncSession,
    work_id: UUID,
    requesting_user_id: UUID,
    cursor: str | None,
    limit: int,
) -> PaginatedResponse[UserBookResponse]:
    """Get paginated reviews for a book, excluding blocked users."""
    # Verify work exists
    work_exists = await db.execute(select(Work.id).where(Work.id == work_id))
    if work_exists.scalar_one_or_none() is None:
        raise book_not_found()

    blocked_subquery = select(Block.blocked_id).where(Block.blocker_id == requesting_user_id)
    blocked_by_subquery = select(Block.blocker_id).where(Block.blocked_id == requesting_user_id)

    stmt = (
        select(UserBook)
        .where(
            UserBook.work_id == work_id,
            UserBook.review_text.isnot(None),
            UserBook.review_text != "",
            UserBook.user_id.notin_(blocked_subquery),
            UserBook.user_id.notin_(blocked_by_subquery),
        )
        .order_by(UserBook.created_at.desc(), UserBook.id.desc())
    )
    stmt = apply_cursor_filter(stmt, UserBook, cursor)
    stmt = stmt.limit(limit + 1)

    result = await db.execute(stmt)
    user_books = list(result.scalars().all())

    has_more = len(user_books) > limit
    if has_more:
        user_books = user_books[:limit]

    items = [UserBookResponse.model_validate(ub) for ub in user_books]
    next_cursor = encode_cursor(user_books[-1].created_at, user_books[-1].id) if has_more else None

    return PaginatedResponse(items=items, next_cursor=next_cursor, has_more=has_more)


async def get_similar_books(db: AsyncSession, work_id: UUID, limit: int) -> list[BookDetail]:
    """Simple collaborative filtering: users who rated this highly also rated..."""
    # Find users who rated this work >= 4.0
    high_raters = select(UserBook.user_id).where(
        UserBook.work_id == work_id,
        UserBook.rating >= 4.0,
    )

    # Find other works those users rated highly, excluding the original
    stmt = (
        select(
            UserBook.work_id,
            func.count().label("cnt"),
            func.avg(UserBook.rating).label("avg_rating"),
        )
        .where(
            UserBook.user_id.in_(high_raters),
            UserBook.work_id != work_id,
            UserBook.rating >= 4.0,
        )
        .group_by(UserBook.work_id)
        .order_by(func.count().desc(), func.avg(UserBook.rating).desc())
        .limit(limit)
    )

    result = await db.execute(stmt)
    rows = result.all()

    if not rows:
        return []

    work_ids = [row.work_id for row in rows]
    works_result = await db.execute(select(Work).where(Work.id.in_(work_ids)))
    works_map = {w.id: w for w in works_result.scalars().all()}

    settings = get_settings()
    similar = []
    for row in rows:
        work = works_map.get(row.work_id)
        if work:
            isbn = await get_best_isbn_for_work(db, work.id)
            similar.append(
                BookDetail(
                    id=work.id,
                    title=work.title,
                    original_title=work.original_title,
                    description=work.description,
                    first_published_year=work.first_published_year,
                    authors=[AuthorBrief(id=a.id, name=a.name) for a in (work.authors or [])],
                    subjects=work.subjects or [],
                    cover_image_url=work.cover_image_url,
                    average_rating=work.average_rating,
                    ratings_count=work.ratings_count,
                    bookshop_url=generate_bookshop_url(
                        isbn, work.title, settings.bookshop_affiliate_id
                    ),
                )
            )

    return similar


async def get_popular_books(
    db: AsyncSession,
    cursor: str | None,
    limit: int,
) -> PaginatedResponse[BookDetail]:
    """Get popular books ordered by ratings count."""
    stmt = (
        select(Work)
        .where(Work.ratings_count > 0)
        .order_by(Work.ratings_count.desc(), Work.created_at.desc(), Work.id.desc())
    )
    stmt = apply_cursor_filter(stmt, Work, cursor)
    stmt = stmt.limit(limit + 1)

    result = await db.execute(stmt)
    works = list(result.scalars().all())

    has_more = len(works) > limit
    if has_more:
        works = works[:limit]

    settings = get_settings()
    items = []
    for w in works:
        isbn = await get_best_isbn_for_work(db, w.id)
        items.append(
            BookDetail(
                id=w.id,
                title=w.title,
                original_title=w.original_title,
                description=w.description,
                first_published_year=w.first_published_year,
                authors=[AuthorBrief(id=a.id, name=a.name) for a in (w.authors or [])],
                subjects=w.subjects or [],
                cover_image_url=w.cover_image_url,
                average_rating=w.average_rating,
                ratings_count=w.ratings_count,
                bookshop_url=generate_bookshop_url(isbn, w.title, settings.bookshop_affiliate_id),
            )
        )

    next_cursor = encode_cursor(works[-1].created_at, works[-1].id) if has_more else None
    return PaginatedResponse(items=items, next_cursor=next_cursor, has_more=has_more)
