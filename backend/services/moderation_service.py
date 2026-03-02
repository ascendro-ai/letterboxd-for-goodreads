"""
Content moderation service.

Provides:
  - AI moderation via OpenAI Moderation API (check_review_content)
  - Community flagging (flag_review)
  - Flag count query (get_flag_count)
"""

from __future__ import annotations

import logging
from uuid import UUID

import httpx
from backend.api.config import get_settings
from backend.api.errors import AppError
from backend.api.model_stubs import ReviewFlag, UserBook
from backend.api.schemas.moderation import FlagReasonSchema, FlagReviewResponse, ModerationResult
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

# Threshold above which we consider a category flagged
MODERATION_THRESHOLD = 0.7


async def check_review_content(text: str) -> ModerationResult:
    """Run text through OpenAI Moderation API.

    On failure (network error, API down, missing key), logs the error and
    returns a passing result so users are not blocked by moderation downtime.
    """
    settings = get_settings()

    if not settings.openai_api_key:
        logger.warning("OpenAI API key not configured — skipping moderation check")
        return ModerationResult(is_flagged=False, categories=[], confidence=0.0)

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                "https://api.openai.com/v1/moderations",
                headers={
                    "Authorization": f"Bearer {settings.openai_api_key}",
                    "Content-Type": "application/json",
                },
                json={"input": text},
            )
            response.raise_for_status()
            data = response.json()

        result = data["results"][0]
        category_scores: dict[str, float] = result["category_scores"]

        flagged_categories: list[str] = []
        max_confidence = 0.0

        for category, score in category_scores.items():
            if score > max_confidence:
                max_confidence = score
            if score > MODERATION_THRESHOLD:
                flagged_categories.append(category)

        return ModerationResult(
            is_flagged=len(flagged_categories) > 0,
            categories=flagged_categories,
            confidence=max_confidence,
        )

    except httpx.HTTPStatusError as e:
        logger.error(
            "OpenAI Moderation API returned error status %d: %s",
            e.response.status_code,
            e.response.text,
        )
        return ModerationResult(is_flagged=False, categories=[], confidence=0.0)

    except httpx.RequestError as e:
        logger.error("OpenAI Moderation API request failed: %s", str(e))
        return ModerationResult(is_flagged=False, categories=[], confidence=0.0)

    except (KeyError, IndexError) as e:
        logger.error("Unexpected moderation API response format: %s", str(e))
        return ModerationResult(is_flagged=False, categories=[], confidence=0.0)


async def flag_review(
    db: AsyncSession,
    flagger_id: UUID,
    user_book_id: UUID,
    reason: FlagReasonSchema,
    description: str | None,
) -> FlagReviewResponse:
    """Flag a review for moderation.

    Validates:
      - The user_book (review) exists
      - The flagger is not the review author
      - No duplicate flag from the same user on the same review
    After creating the flag, checks if total unique flaggers >= 3 and
    auto-hides the review if so.
    """
    # Verify the user_book exists
    result = await db.execute(select(UserBook).where(UserBook.id == user_book_id))
    user_book = result.scalar_one_or_none()
    if user_book is None:
        raise AppError(
            status_code=404,
            code="USER_BOOK_NOT_FOUND",
            message="No review found with the given ID.",
        )

    # Cannot flag your own review
    if str(user_book.user_id) == str(flagger_id):
        raise AppError(
            status_code=403,
            code="CANNOT_FLAG_OWN_REVIEW",
            message="You cannot flag your own review.",
        )

    # Check for duplicate flag
    existing = await db.execute(
        select(ReviewFlag).where(
            ReviewFlag.flagger_user_id == flagger_id,
            ReviewFlag.user_book_id == user_book_id,
        )
    )
    if existing.scalar_one_or_none() is not None:
        raise AppError(
            status_code=409,
            code="DUPLICATE_FLAG",
            message="You have already flagged this review.",
        )

    # Create the flag
    flag = ReviewFlag(
        flagger_user_id=flagger_id,
        user_book_id=user_book_id,
        reason=reason.value,
        description=description,
        status="pending",
    )
    db.add(flag)
    await db.flush()
    await db.refresh(flag)

    # Check total unique flags — auto-hide at 3
    flag_count = await get_flag_count(db, user_book_id)
    if flag_count >= 3:
        user_book.is_hidden = True
        await db.flush()

    return FlagReviewResponse(
        id=flag.id,
        reason=flag.reason if isinstance(flag.reason, str) else flag.reason.value,
        status=flag.status if isinstance(flag.status, str) else flag.status.value,
        created_at=flag.created_at,
    )


async def get_flag_count(db: AsyncSession, user_book_id: UUID) -> int:
    """Return the number of unique users who have flagged this review."""
    result = await db.execute(
        select(func.count(ReviewFlag.id)).where(
            ReviewFlag.user_book_id == user_book_id,
        )
    )
    return result.scalar_one()
