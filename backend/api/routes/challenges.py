"""Reading challenge routes: set goals, track progress."""

from __future__ import annotations

from uuid import UUID

from backend.api.deps import DB, CurrentUser
from backend.api.schemas.challenges import (
    ChallengeResponse,
    CreateChallengeRequest,
    UpdateChallengeRequest,
)
from backend.services import challenge_service
from fastapi import APIRouter, status

router = APIRouter()


@router.post("/me/challenges", response_model=ChallengeResponse, status_code=status.HTTP_201_CREATED)
async def create_challenge(
    request: CreateChallengeRequest,
    db: DB,
    current_user: CurrentUser,
) -> ChallengeResponse:
    """Set a reading goal for a year."""
    return await challenge_service.create_challenge(db, current_user.id, request)


@router.get("/me/challenges", response_model=list[ChallengeResponse])
async def list_challenges(
    db: DB,
    current_user: CurrentUser,
) -> list[ChallengeResponse]:
    """List all your reading challenges."""
    return await challenge_service.list_challenges(db, current_user.id)


@router.get("/me/challenges/{year}", response_model=ChallengeResponse)
async def get_challenge(
    year: int,
    db: DB,
    current_user: CurrentUser,
) -> ChallengeResponse:
    """Get your challenge for a specific year with books."""
    return await challenge_service.get_challenge(db, current_user.id, year)


@router.patch("/me/challenges/{year}", response_model=ChallengeResponse)
async def update_challenge(
    year: int,
    request: UpdateChallengeRequest,
    db: DB,
    current_user: CurrentUser,
) -> ChallengeResponse:
    """Update your reading goal for a year."""
    return await challenge_service.update_challenge(db, current_user.id, year, request)


@router.get("/users/{user_id}/challenges/{year}", response_model=ChallengeResponse)
async def get_user_challenge(
    user_id: UUID,
    year: int,
    db: DB,
    current_user: CurrentUser,
) -> ChallengeResponse:
    """View another user's challenge for a specific year."""
    return await challenge_service.get_challenge(db, user_id, year)
