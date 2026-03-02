"""Reading statistics routes."""

from __future__ import annotations

from uuid import UUID

from backend.api.deps import DB, CurrentUser
from backend.api.errors import blocked_user, user_not_found
from backend.api.model_stubs import User
from backend.api.schemas.stats import ReadingStats
from backend.services import stats_service
from backend.services.social_service import is_blocked
from fastapi import APIRouter
from sqlalchemy import select

router = APIRouter()


@router.get("/me/stats", response_model=ReadingStats)
async def get_my_stats(
    db: DB,
    current_user: CurrentUser,
) -> ReadingStats:
    """Get your own reading statistics."""
    return await stats_service.get_reading_stats(db, current_user.id)


@router.get("/users/{user_id}/stats", response_model=ReadingStats)
async def get_user_stats(
    user_id: UUID,
    db: DB,
    current_user: CurrentUser,
) -> ReadingStats:
    """Get another user's reading statistics.

    Returns 404 if the user has hidden their stats.
    """
    if await is_blocked(db, current_user.id, user_id):
        raise blocked_user()

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise user_not_found()

    if getattr(user, "hide_reading_stats", False):
        raise user_not_found()  # Reuse 404 to not leak existence

    return await stats_service.get_reading_stats(db, user_id)
