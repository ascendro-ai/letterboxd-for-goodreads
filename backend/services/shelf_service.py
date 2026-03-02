from __future__ import annotations

from uuid import UUID

from backend.api.config import get_settings
from backend.api.errors import blocked_user, shelf_limit_reached, shelf_not_found
from backend.api.model_stubs import Shelf, ShelfBook, User, UserBook, Work
from backend.api.schemas.books import AuthorBrief, BookBrief
from backend.api.schemas.shelves import (
    CreateShelfRequest,
    ShelfDetailResponse,
    ShelfResponse,
    UpdateShelfRequest,
)
from backend.api.schemas.user_books import UserBookResponse
from backend.api.utils import slugify
from backend.services.social_service import is_blocked
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession


async def create_shelf(
    db: AsyncSession,
    current_user: User,
    request: CreateShelfRequest,
) -> ShelfResponse:
    """Create a new shelf. Enforces 20-shelf limit for free users."""
    settings = get_settings()

    # Count existing shelves
    count_result = await db.execute(
        select(func.count()).select_from(Shelf).where(Shelf.user_id == current_user.id)
    )
    shelf_count = count_result.scalar() or 0

    if not current_user.is_premium and shelf_count >= settings.max_shelves_free:
        raise shelf_limit_reached()

    # Get max display_order
    max_order_result = await db.execute(
        select(func.max(Shelf.display_order)).where(Shelf.user_id == current_user.id)
    )
    max_order = max_order_result.scalar() or 0

    shelf = Shelf(
        user_id=current_user.id,
        name=request.name,
        slug=slugify(request.name),
        description=request.description,
        is_public=request.is_public,
        display_order=max_order + 1,
    )
    db.add(shelf)
    await db.flush()

    return ShelfResponse(
        id=shelf.id,
        name=shelf.name,
        slug=shelf.slug,
        description=shelf.description,
        is_public=shelf.is_public,
        display_order=shelf.display_order,
        book_count=0,
    )


async def list_shelves(db: AsyncSession, user_id: UUID) -> list[ShelfResponse]:
    """List all shelves for a user with book counts."""
    book_count_subq = (
        select(func.count())
        .select_from(ShelfBook)
        .where(ShelfBook.shelf_id == Shelf.id)
        .correlate(Shelf)
        .scalar_subquery()
    )

    result = await db.execute(
        select(Shelf, book_count_subq.label("book_count"))
        .where(Shelf.user_id == user_id)
        .order_by(Shelf.display_order)
    )
    rows = result.all()

    return [
        ShelfResponse(
            id=shelf.id,
            name=shelf.name,
            slug=shelf.slug,
            description=shelf.description,
            is_public=shelf.is_public,
            display_order=shelf.display_order,
            book_count=book_count or 0,
        )
        for shelf, book_count in rows
    ]


async def update_shelf(
    db: AsyncSession,
    user_id: UUID,
    shelf_id: UUID,
    request: UpdateShelfRequest,
) -> ShelfResponse:
    """Update a shelf. Ownership check."""
    shelf = await _get_owned_shelf(db, user_id, shelf_id)

    if request.name is not None:
        shelf.name = request.name
        shelf.slug = slugify(request.name)
    if request.description is not None:
        shelf.description = request.description
    if request.is_public is not None:
        shelf.is_public = request.is_public
    if request.display_order is not None:
        shelf.display_order = request.display_order

    await db.flush()

    # Get book count
    count_result = await db.execute(
        select(func.count()).select_from(ShelfBook).where(ShelfBook.shelf_id == shelf_id)
    )
    book_count = count_result.scalar() or 0

    return ShelfResponse(
        id=shelf.id,
        name=shelf.name,
        slug=shelf.slug,
        description=shelf.description,
        is_public=shelf.is_public,
        display_order=shelf.display_order,
        book_count=book_count,
    )


async def delete_shelf(db: AsyncSession, user_id: UUID, shelf_id: UUID) -> None:
    """Delete a shelf and its book associations."""
    shelf = await _get_owned_shelf(db, user_id, shelf_id)

    await db.execute(ShelfBook.__table__.delete().where(ShelfBook.shelf_id == shelf_id))
    await db.delete(shelf)
    await db.flush()


async def add_book_to_shelf(
    db: AsyncSession, user_id: UUID, shelf_id: UUID, user_book_id: UUID
) -> None:
    """Add a book to a shelf. Verifies ownership of both shelf and user_book."""
    await _get_owned_shelf(db, user_id, shelf_id)

    # Verify user_book ownership
    ub_result = await db.execute(
        select(UserBook).where(UserBook.id == user_book_id, UserBook.user_id == user_id)
    )
    if ub_result.scalar_one_or_none() is None:
        from backend.api.errors import user_book_not_found

        raise user_book_not_found()

    # Get max position
    max_pos_result = await db.execute(
        select(func.max(ShelfBook.position)).where(ShelfBook.shelf_id == shelf_id)
    )
    max_pos = max_pos_result.scalar() or 0

    shelf_book = ShelfBook(
        shelf_id=shelf_id,
        user_book_id=user_book_id,
        position=max_pos + 1,
    )
    db.add(shelf_book)
    await db.flush()


async def remove_book_from_shelf(
    db: AsyncSession, user_id: UUID, shelf_id: UUID, user_book_id: UUID
) -> None:
    """Remove a book from a shelf."""
    await _get_owned_shelf(db, user_id, shelf_id)

    await db.execute(
        ShelfBook.__table__.delete().where(
            ShelfBook.shelf_id == shelf_id, ShelfBook.user_book_id == user_book_id
        )
    )
    await db.flush()


async def list_user_shelves(
    db: AsyncSession, requesting_user_id: UUID, target_user_id: UUID
) -> list[ShelfResponse]:
    """List another user's public shelves. Block check."""
    if await is_blocked(db, requesting_user_id, target_user_id):
        raise blocked_user()

    book_count_subq = (
        select(func.count())
        .select_from(ShelfBook)
        .where(ShelfBook.shelf_id == Shelf.id)
        .correlate(Shelf)
        .scalar_subquery()
    )

    result = await db.execute(
        select(Shelf, book_count_subq.label("book_count"))
        .where(Shelf.user_id == target_user_id, Shelf.is_public == True)  # noqa: E712
        .order_by(Shelf.display_order)
    )
    rows = result.all()

    return [
        ShelfResponse(
            id=shelf.id,
            name=shelf.name,
            slug=shelf.slug,
            description=shelf.description,
            is_public=shelf.is_public,
            display_order=shelf.display_order,
            book_count=book_count or 0,
        )
        for shelf, book_count in rows
    ]


async def get_shelf_detail(
    db: AsyncSession,
    requesting_user_id: UUID,
    target_user_id: UUID,
    shelf_id: UUID,
    cursor: str | None,
    limit: int,
) -> ShelfDetailResponse:
    """Get shelf detail with books. Public check, block check."""
    if await is_blocked(db, requesting_user_id, target_user_id):
        raise blocked_user()

    result = await db.execute(
        select(Shelf).where(Shelf.id == shelf_id, Shelf.user_id == target_user_id)
    )
    shelf = result.scalar_one_or_none()
    if shelf is None:
        raise shelf_not_found()

    # If not the owner, must be public
    if str(requesting_user_id) != str(target_user_id) and not shelf.is_public:
        raise shelf_not_found()

    # Get book count
    count_result = await db.execute(
        select(func.count()).select_from(ShelfBook).where(ShelfBook.shelf_id == shelf_id)
    )
    book_count = count_result.scalar() or 0

    # Get books
    stmt = (
        select(UserBook)
        .join(ShelfBook, ShelfBook.user_book_id == UserBook.id)
        .where(ShelfBook.shelf_id == shelf_id)
        .order_by(ShelfBook.position)
    )
    stmt = stmt.limit(limit + 1)

    ub_result = await db.execute(stmt)
    user_books = list(ub_result.scalars().all())

    has_more = len(user_books) > limit
    if has_more:
        user_books = user_books[:limit]

    # Load works
    if user_books:
        work_ids = [ub.work_id for ub in user_books]
        works_result = await db.execute(select(Work).where(Work.id.in_(work_ids)))
        works_map = {w.id: w for w in works_result.scalars().all()}
    else:
        works_map = {}

    books = []
    for ub in user_books:
        work = works_map.get(ub.work_id)
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
        books.append(
            UserBookResponse(
                id=ub.id,
                work_id=ub.work_id,
                status=ub.status,
                rating=ub.rating,
                review_text=ub.review_text,
                has_spoilers=ub.has_spoilers,
                started_at=ub.started_at,
                finished_at=ub.finished_at,
                is_imported=ub.is_imported,
                created_at=ub.created_at,
                updated_at=ub.updated_at,
                book=book_brief,
            )
        )

    return ShelfDetailResponse(
        id=shelf.id,
        name=shelf.name,
        slug=shelf.slug,
        description=shelf.description,
        is_public=shelf.is_public,
        display_order=shelf.display_order,
        book_count=book_count,
        books=books,
    )


async def _get_owned_shelf(db: AsyncSession, user_id: UUID, shelf_id: UUID) -> Shelf:
    """Load a shelf and verify ownership."""
    result = await db.execute(select(Shelf).where(Shelf.id == shelf_id, Shelf.user_id == user_id))
    shelf = result.scalar_one_or_none()
    if shelf is None:
        raise shelf_not_found()
    return shelf
