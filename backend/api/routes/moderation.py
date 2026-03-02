from __future__ import annotations

from uuid import UUID

from backend.api.deps import DB, CurrentUser
from backend.api.schemas.moderation import FlagReviewRequest, FlagReviewResponse
from backend.services import moderation_service
from fastapi import APIRouter, status

router = APIRouter()


@router.post(
    "/reviews/{user_book_id}/flag",
    response_model=FlagReviewResponse,
    status_code=status.HTTP_201_CREATED,
)
async def flag_review(
    user_book_id: UUID,
    request: FlagReviewRequest,
    db: DB,
    current_user: CurrentUser,
) -> FlagReviewResponse:
    """Flag a review for content moderation."""
    return await moderation_service.flag_review(
        db,
        current_user.id,
        user_book_id,
        request.reason,
        request.description,
    )
