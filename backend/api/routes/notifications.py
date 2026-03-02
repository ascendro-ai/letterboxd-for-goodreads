"""Push notification routes: device registration, unread count.

Note: GET /notifications and POST /notifications/read are handled by feed.py
(registered first). This router only handles device token management and
the unread badge count.
"""

from __future__ import annotations

from backend.api.deps import DB, CurrentUser
from backend.api.schemas.notifications import (
    RegisterDeviceRequest,
    UnreadCountResponse,
    UnregisterDeviceRequest,
)
from backend.services import notification_service
from fastapi import APIRouter, status

router = APIRouter()


@router.post("/me/devices", status_code=status.HTTP_201_CREATED)
async def register_device(
    request: RegisterDeviceRequest,
    db: DB,
    current_user: CurrentUser,
) -> dict[str, str]:
    """Register a device token for push notifications."""
    await notification_service.register_device(
        db, current_user.id, request.device_token, request.platform
    )
    return {"status": "registered"}


@router.delete("/me/devices", status_code=status.HTTP_200_OK)
async def unregister_device(
    request: UnregisterDeviceRequest,
    db: DB,
    current_user: CurrentUser,
) -> dict[str, str]:
    """Unregister a device token (logout/disable notifications)."""
    await notification_service.unregister_device(db, current_user.id, request.device_token)
    return {"status": "unregistered"}


@router.get("/notifications/unread-count", response_model=UnreadCountResponse)
async def get_unread_count(
    db: DB,
    current_user: CurrentUser,
) -> UnreadCountResponse:
    """Get the count of unread notifications (for badge display)."""
    count = await notification_service.get_unread_count(db, current_user.id)
    return UnreadCountResponse(count=count)
