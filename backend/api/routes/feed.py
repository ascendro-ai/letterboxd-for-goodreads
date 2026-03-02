from __future__ import annotations

from backend.api.deps import DB, CurrentUser
from backend.api.schemas.common import PaginatedResponse
from backend.api.schemas.feed import FeedItem, MarkReadRequest, NotificationItem
from backend.services import feed_service
from fastapi import APIRouter, Query

router = APIRouter()


@router.get("/feed", response_model=PaginatedResponse[FeedItem])
async def get_feed(
    db: DB,
    current_user: CurrentUser,
    cursor: str | None = None,
    limit: int = Query(20, ge=1, le=100),
) -> PaginatedResponse[FeedItem]:
    """Get activity feed. Returns popular feed for users with no follows (cold start)."""
    return await feed_service.get_feed(db, current_user.id, cursor, limit)


@router.get("/notifications", response_model=PaginatedResponse[NotificationItem])
async def get_notifications(
    db: DB,
    current_user: CurrentUser,
    cursor: str | None = None,
    limit: int = Query(20, ge=1, le=100),
) -> PaginatedResponse[NotificationItem]:
    """Get your notifications (paginated)."""
    return await feed_service.get_notifications(db, current_user.id, cursor, limit)


@router.post("/notifications/read")
async def mark_notifications_read(
    request: MarkReadRequest,
    db: DB,
    current_user: CurrentUser,
) -> dict[str, str]:
    """Mark notifications as read."""
    await feed_service.mark_notifications_read(db, current_user.id, request.notification_ids)
    return {"message": "Notifications marked as read"}
