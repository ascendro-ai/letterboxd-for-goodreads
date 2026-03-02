"""Service layer for reading challenges."""

from __future__ import annotations

from datetime import datetime, timezone
from uuid import UUID

from backend.api.errors import AppError
from backend.api.model_stubs import ChallengeBook, ReadingChallenge, UserBook
from backend.api.schemas.challenges import (
    ChallengeBookItem,
    ChallengeResponse,
    CreateChallengeRequest,
    UpdateChallengeRequest,
)
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession


async def create_challenge(
    db: AsyncSession, user_id: UUID, request: CreateChallengeRequest
) -> ChallengeResponse:
    """Create a reading challenge for a year. One per user per year."""
    existing = await db.execute(
        select(ReadingChallenge).where(
            ReadingChallenge.user_id == user_id,
            ReadingChallenge.year == request.year,
        )
    )
    if existing.scalar_one_or_none() is not None:
        raise AppError(
            status_code=409,
            code="CHALLENGE_EXISTS",
            message=f"You already have a challenge for {request.year}.",
        )

    challenge = ReadingChallenge(
        user_id=user_id,
        year=request.year,
        goal_count=request.goal_count,
        current_count=0,
        is_complete=False,
    )
    db.add(challenge)
    await db.flush()
    await db.refresh(challenge)

    return _to_response(challenge, books=None)


async def list_challenges(db: AsyncSession, user_id: UUID) -> list[ChallengeResponse]:
    """List all challenges for a user, newest year first."""
    result = await db.execute(
        select(ReadingChallenge)
        .where(ReadingChallenge.user_id == user_id)
        .order_by(ReadingChallenge.year.desc())
    )
    challenges = result.scalars().all()
    return [_to_response(c, books=None) for c in challenges]


async def get_challenge(
    db: AsyncSession, user_id: UUID, year: int
) -> ChallengeResponse:
    """Get a specific year's challenge with its books."""
    result = await db.execute(
        select(ReadingChallenge).where(
            ReadingChallenge.user_id == user_id,
            ReadingChallenge.year == year,
        )
    )
    challenge = result.scalar_one_or_none()
    if challenge is None:
        raise AppError(
            status_code=404,
            code="CHALLENGE_NOT_FOUND",
            message=f"No reading challenge found for {year}.",
        )

    # Fetch challenge books
    cb_result = await db.execute(
        select(ChallengeBook, UserBook)
        .join(UserBook, ChallengeBook.user_book_id == UserBook.id)
        .where(ChallengeBook.challenge_id == challenge.id)
    )
    rows = cb_result.all()

    books = []
    for cb, ub in rows:
        work = ub.work
        books.append(
            ChallengeBookItem(
                user_book_id=ub.id if hasattr(ub.id, "hex") else UUID(str(ub.id)),
                work_title=work.title if work else "Unknown",
                authors=[a.name for a in work.authors] if work and work.authors else [],
                cover_image_url=work.cover_image_url if work else None,
                finished_at=ub.finished_at,
            )
        )

    return _to_response(challenge, books=books)


async def update_challenge(
    db: AsyncSession, user_id: UUID, year: int, request: UpdateChallengeRequest
) -> ChallengeResponse:
    """Update a challenge's goal count."""
    result = await db.execute(
        select(ReadingChallenge).where(
            ReadingChallenge.user_id == user_id,
            ReadingChallenge.year == year,
        )
    )
    challenge = result.scalar_one_or_none()
    if challenge is None:
        raise AppError(
            status_code=404,
            code="CHALLENGE_NOT_FOUND",
            message=f"No reading challenge found for {year}.",
        )

    challenge.goal_count = request.goal_count

    # Re-evaluate completion
    if challenge.current_count >= challenge.goal_count:
        if not challenge.is_complete:
            challenge.is_complete = True
            challenge.completed_at = datetime.now(timezone.utc)
    else:
        challenge.is_complete = False
        challenge.completed_at = None

    await db.flush()
    await db.refresh(challenge)

    return _to_response(challenge, books=None)


async def auto_add_book_to_challenge(
    db: AsyncSession, user_id: UUID, user_book: UserBook
) -> None:
    """Auto-add a book to the active challenge when marked as read.

    Called from user_book_service after setting status='read' with finished_at.
    """
    if user_book.status != "read" or user_book.finished_at is None:
        return

    challenge_year = user_book.finished_at.year
    result = await db.execute(
        select(ReadingChallenge).where(
            ReadingChallenge.user_id == user_id,
            ReadingChallenge.year == challenge_year,
        )
    )
    challenge = result.scalar_one_or_none()
    if challenge is None:
        return

    # Check if already added
    existing = await db.execute(
        select(ChallengeBook).where(
            ChallengeBook.challenge_id == challenge.id,
            ChallengeBook.user_book_id == user_book.id,
        )
    )
    if existing.scalar_one_or_none() is not None:
        return

    db.add(
        ChallengeBook(
            challenge_id=challenge.id,
            user_book_id=user_book.id,
        )
    )
    challenge.current_count += 1

    if challenge.current_count >= challenge.goal_count and not challenge.is_complete:
        challenge.is_complete = True
        challenge.completed_at = datetime.now(timezone.utc)

    await db.flush()


def _to_response(
    challenge: ReadingChallenge, books: list[ChallengeBookItem] | None
) -> ChallengeResponse:
    return ChallengeResponse(
        id=challenge.id if hasattr(challenge.id, "hex") else UUID(str(challenge.id)),
        year=challenge.year,
        goal_count=challenge.goal_count,
        current_count=challenge.current_count,
        is_complete=challenge.is_complete,
        completed_at=challenge.completed_at,
        created_at=challenge.created_at,
        books=books,
    )
