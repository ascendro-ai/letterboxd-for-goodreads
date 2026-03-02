from __future__ import annotations

from uuid import UUID

from backend.api.deps import DB, CurrentUser
from backend.api.schemas.books import BookDetail, BookSearchResult
from backend.api.schemas.common import PaginatedResponse
from backend.api.schemas.user_books import UserBookResponse
from backend.services import book_service
from fastapi import APIRouter, Query

router = APIRouter()


@router.get("/search", response_model=PaginatedResponse[BookSearchResult])
async def search_books(
    db: DB,
    current_user: CurrentUser,
    q: str = Query(min_length=1),
    cursor: str | None = None,
    limit: int = Query(20, ge=1, le=100),
) -> PaginatedResponse[BookSearchResult]:
    """Search books by title/author using full-text search + fuzzy matching."""
    return await book_service.search_books(db, q, cursor, limit)


@router.get("/popular", response_model=PaginatedResponse[BookDetail])
async def popular_books(
    db: DB,
    current_user: CurrentUser,
    cursor: str | None = None,
    limit: int = Query(20, ge=1, le=100),
) -> PaginatedResponse[BookDetail]:
    """Get popular books this week (by recent rating activity)."""
    return await book_service.get_popular_books(db, cursor, limit)


@router.get("/isbn/{isbn}", response_model=BookDetail)
async def lookup_by_isbn(
    isbn: str,
    db: DB,
    current_user: CurrentUser,
) -> BookDetail:
    """Look up a book by ISBN (for barcode scanning)."""
    return await book_service.lookup_by_isbn(db, isbn)


@router.get("/{work_id}", response_model=BookDetail)
async def get_book_detail(
    work_id: UUID,
    db: DB,
    current_user: CurrentUser,
) -> BookDetail:
    """Get full book detail by work ID."""
    return await book_service.get_book_detail(db, work_id)


@router.get("/{work_id}/reviews", response_model=PaginatedResponse[UserBookResponse])
async def get_book_reviews(
    work_id: UUID,
    db: DB,
    current_user: CurrentUser,
    cursor: str | None = None,
    limit: int = Query(20, ge=1, le=100),
) -> PaginatedResponse[UserBookResponse]:
    """Get reviews for a book (paginated)."""
    return await book_service.get_book_reviews(db, work_id, current_user.id, cursor, limit)


@router.get("/{work_id}/similar", response_model=list[BookDetail])
async def get_similar_books(
    work_id: UUID,
    db: DB,
    current_user: CurrentUser,
    limit: int = Query(10, ge=1, le=50),
) -> list[BookDetail]:
    """Get books similar to this one (collaborative filtering)."""
    return await book_service.get_similar_books(db, work_id, limit)
