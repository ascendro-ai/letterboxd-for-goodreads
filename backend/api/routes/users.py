"""User profile and social graph routes: follow, block, mute, taste matches."""

from __future__ import annotations

from uuid import UUID

from backend.api.deps import DB, CurrentUser
from backend.api.schemas.common import PaginatedResponse
from backend.api.schemas.social import TasteMatchResponse
from backend.api.schemas.users import UpdateProfileRequest, UserBrief, UserProfile
from backend.services import social_service, user_service
from fastapi import APIRouter, Query, status

router = APIRouter()


# --- Profile ---


@router.get("/me", response_model=UserProfile)
async def get_my_profile(
    db: DB,
    current_user: CurrentUser,
) -> UserProfile:
    """Get your own profile with counts."""
    return await user_service.get_profile(db, current_user.id, current_user.id)


@router.patch("/me", response_model=UserProfile)
async def update_my_profile(
    request: UpdateProfileRequest,
    db: DB,
    current_user: CurrentUser,
) -> UserProfile:
    """Update your profile (display name, bio, avatar, favorite books)."""
    return await user_service.update_profile(db, current_user.id, request)


@router.get("/me/taste-matches", response_model=list[TasteMatchResponse])
async def get_taste_matches(
    db: DB,
    current_user: CurrentUser,
    limit: int = Query(20, ge=1, le=100),
) -> list[TasteMatchResponse]:
    """Get your taste match scores with other users."""
    return await social_service.get_taste_matches(db, current_user.id, limit)


@router.get("/users/search", response_model=PaginatedResponse[UserBrief])
async def search_users(
    db: DB,
    current_user: CurrentUser,
    q: str = Query(min_length=1),
    cursor: str | None = None,
    limit: int = Query(20, ge=1, le=100),
) -> PaginatedResponse[UserBrief]:
    """Search users by username or display name."""
    return await user_service.search_users(db, q, cursor, limit)


@router.get("/users/{user_id}", response_model=UserProfile)
async def get_user_profile(
    user_id: UUID,
    db: DB,
    current_user: CurrentUser,
) -> UserProfile:
    """View another user's profile."""
    return await user_service.get_profile(db, current_user.id, user_id)


# --- Social: Follow ---


@router.post("/users/{user_id}/follow", status_code=status.HTTP_201_CREATED)
async def follow_user(
    user_id: UUID,
    db: DB,
    current_user: CurrentUser,
) -> dict[str, str]:
    """Follow a user."""
    await social_service.follow_user(db, current_user.id, user_id)
    return {"message": "Followed"}


@router.delete("/users/{user_id}/follow")
async def unfollow_user(
    user_id: UUID,
    db: DB,
    current_user: CurrentUser,
) -> dict[str, str]:
    """Unfollow a user."""
    await social_service.unfollow_user(db, current_user.id, user_id)
    return {"message": "Unfollowed"}


@router.get("/users/{user_id}/followers", response_model=PaginatedResponse[UserBrief])
async def list_followers(
    user_id: UUID,
    db: DB,
    current_user: CurrentUser,
    cursor: str | None = None,
    limit: int = Query(20, ge=1, le=100),
) -> PaginatedResponse[UserBrief]:
    """List a user's followers."""
    return await social_service.list_followers(db, user_id, cursor, limit)


@router.get("/users/{user_id}/following", response_model=PaginatedResponse[UserBrief])
async def list_following(
    user_id: UUID,
    db: DB,
    current_user: CurrentUser,
    cursor: str | None = None,
    limit: int = Query(20, ge=1, le=100),
) -> PaginatedResponse[UserBrief]:
    """List users that a user follows."""
    return await social_service.list_following(db, user_id, cursor, limit)


# --- Social: Block & Mute ---


@router.post("/users/{user_id}/block", status_code=status.HTTP_201_CREATED)
async def block_user(
    user_id: UUID,
    db: DB,
    current_user: CurrentUser,
) -> dict[str, str]:
    """Block a user (full separation)."""
    await social_service.block_user(db, current_user.id, user_id)
    return {"message": "Blocked"}


@router.delete("/users/{user_id}/block")
async def unblock_user(
    user_id: UUID,
    db: DB,
    current_user: CurrentUser,
) -> dict[str, str]:
    """Unblock a user."""
    await social_service.unblock_user(db, current_user.id, user_id)
    return {"message": "Unblocked"}


@router.post("/users/{user_id}/mute", status_code=status.HTTP_201_CREATED)
async def mute_user(
    user_id: UUID,
    db: DB,
    current_user: CurrentUser,
) -> dict[str, str]:
    """Mute a user (hidden from your feed, they don't know)."""
    await social_service.mute_user(db, current_user.id, user_id)
    return {"message": "Muted"}


@router.delete("/users/{user_id}/mute")
async def unmute_user(
    user_id: UUID,
    db: DB,
    current_user: CurrentUser,
) -> dict[str, str]:
    """Unmute a user."""
    await social_service.unmute_user(db, current_user.id, user_id)
    return {"message": "Unmuted"}
