"""Series routes: view series details and reading progress."""

from __future__ import annotations

from uuid import UUID

from backend.api.deps import DB, CurrentUser
from backend.api.schemas.series import SeriesProgressResponse, SeriesResponse
from backend.services import series_service
from fastapi import APIRouter

router = APIRouter()


@router.get("/series/{series_id}", response_model=SeriesResponse)
async def get_series(
    series_id: UUID,
    db: DB,
    current_user: CurrentUser,
) -> SeriesResponse:
    """Get a series with its books in order, including user's reading status."""
    return await series_service.get_series(db, series_id, user_id=current_user.id)


@router.get("/series/{series_id}/progress", response_model=SeriesProgressResponse)
async def get_series_progress(
    series_id: UUID,
    db: DB,
    current_user: CurrentUser,
) -> SeriesProgressResponse:
    """Get the current user's reading progress through a series."""
    return await series_service.get_series_progress(db, series_id, current_user.id)


@router.get("/books/{work_id}/series", response_model=list[SeriesResponse])
async def get_book_series(
    work_id: UUID,
    db: DB,
    current_user: CurrentUser,
) -> list[SeriesResponse]:
    """Get all series a book belongs to."""
    return await series_service.get_book_series(db, work_id)
