from __future__ import annotations

from backend.api.deps import DB, CurrentUser
from backend.api.schemas.discovery import (
    ContactHashesRequest,
    DiscoverUsersResponse,
)
from backend.services import discover_service
from fastapi import APIRouter, Query

router = APIRouter()


@router.post("/contacts", response_model=DiscoverUsersResponse)
async def find_contacts(
    request: ContactHashesRequest,
    db: DB,
    current_user: CurrentUser,
) -> DiscoverUsersResponse:
    """Upload hashed contacts (SHA-256 hex of emails/phones) to find registered friends."""
    users = await discover_service.find_contacts(db, current_user.id, request.hashes)
    return DiscoverUsersResponse(users=users)


@router.get("/taste", response_model=DiscoverUsersResponse)
async def taste_suggestions(
    db: DB,
    current_user: CurrentUser,
    limit: int = Query(20, ge=1, le=100),
) -> DiscoverUsersResponse:
    """Get users with high taste match scores that you're not yet following."""
    users = await discover_service.get_taste_suggestions(db, current_user.id, limit)
    return DiscoverUsersResponse(users=users)


@router.get("/popular", response_model=DiscoverUsersResponse)
async def popular_users(
    db: DB,
    current_user: CurrentUser,
    limit: int = Query(20, ge=1, le=100),
) -> DiscoverUsersResponse:
    """Get popular users to follow, ordered by follower count."""
    users = await discover_service.get_popular_users(db, current_user.id, limit)
    return DiscoverUsersResponse(users=users)
