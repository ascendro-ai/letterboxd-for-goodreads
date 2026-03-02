"""Reading log routes: log, rate, review, update status."""

from __future__ import annotations

from uuid import UUID

from backend.api.deps import DB, CurrentUser
from backend.api.errors import AppError
from backend.api.model_stubs import ReviewFlag
from backend.api.schemas.common import PaginatedResponse
from backend.api.schemas.user_books import LogBookRequest, UpdateBookRequest, UserBookResponse
from backend.services import user_book_service
from backend.services.moderation_service import check_review_content
from fastapi import APIRouter, Query, status

router = APIRouter()


@router.post("/me/books", response_model=UserBookResponse, status_code=status.HTTP_201_CREATED)
async def log_book(
    request: LogBookRequest,
    db: DB,
    current_user: CurrentUser,
) -> UserBookResponse:
    """Log a book: set status, rate, and review."""
    moderation_result = None
    if request.review_text:
        moderation_result = await check_review_content(request.review_text)
        if moderation_result.is_flagged:
            raise AppError(
                status_code=422,
                code="REVIEW_FLAGGED",
                message="Your review was flagged for potentially violating community guidelines.",
            )

    result = await user_book_service.log_book(db, current_user.id, request)

    # If borderline, auto-create a review flag for manual review
    if moderation_result and moderation_result.is_borderline:
        flag = ReviewFlag(
            flagger_user_id=current_user.id,
            user_book_id=result.id,
            reason="other",
            description=(
                f"Auto-flagged by AI moderation (confidence: {moderation_result.confidence:.2f}, "
                f"categories: {', '.join(moderation_result.categories) or 'none'})"
            ),
            status="pending",
        )
        db.add(flag)
        await db.flush()

    return result


@router.patch("/me/books/{user_book_id}", response_model=UserBookResponse)
async def update_book(
    user_book_id: UUID,
    request: UpdateBookRequest,
    db: DB,
    current_user: CurrentUser,
) -> UserBookResponse:
    """Update a logged book's status, rating, or review."""
    moderation_result = None
    if request.review_text:
        moderation_result = await check_review_content(request.review_text)
        if moderation_result.is_flagged:
            raise AppError(
                status_code=422,
                code="REVIEW_FLAGGED",
                message="Your review was flagged for potentially violating community guidelines.",
            )

    result = await user_book_service.update_book(db, current_user.id, user_book_id, request)

    if moderation_result and moderation_result.is_borderline:
        flag = ReviewFlag(
            flagger_user_id=current_user.id,
            user_book_id=result.id,
            reason="other",
            description=(
                f"Auto-flagged by AI moderation (confidence: {moderation_result.confidence:.2f}, "
                f"categories: {', '.join(moderation_result.categories) or 'none'})"
            ),
            status="pending",
        )
        db.add(flag)
        await db.flush()

    return result


@router.delete("/me/books/{user_book_id}", status_code=status.HTTP_200_OK)
async def delete_book(
    user_book_id: UUID,
    db: DB,
    current_user: CurrentUser,
) -> dict[str, str]:
    """Remove a book from your library."""
    await user_book_service.delete_book(db, current_user.id, user_book_id)
    return {"message": "Book removed"}


@router.get("/me/books", response_model=PaginatedResponse[UserBookResponse])
async def list_my_books(
    db: DB,
    current_user: CurrentUser,
    status_filter: str | None = Query(None, alias="status"),
    cursor: str | None = None,
    limit: int = Query(20, ge=1, le=100),
) -> PaginatedResponse[UserBookResponse]:
    """List your logged books, optionally filtered by status."""
    return await user_book_service.list_user_books(
        db, current_user.id, current_user.id, status_filter, cursor, limit
    )


@router.get("/users/{user_id}/books", response_model=PaginatedResponse[UserBookResponse])
async def list_user_books(
    user_id: UUID,
    db: DB,
    current_user: CurrentUser,
    status_filter: str | None = Query(None, alias="status"),
    cursor: str | None = None,
    limit: int = Query(20, ge=1, le=100),
) -> PaginatedResponse[UserBookResponse]:
    """List another user's logged books."""
    return await user_book_service.list_user_books(
        db, current_user.id, user_id, status_filter, cursor, limit
    )
