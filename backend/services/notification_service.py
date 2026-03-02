"""Push notification service: register devices, send notifications, manage read state."""

from __future__ import annotations

import logging
from uuid import UUID

from backend.api.model_stubs import DeviceToken, Notification
from backend.api.pagination import apply_cursor_filter, encode_cursor
from backend.api.schemas.common import PaginatedResponse
from backend.api.schemas.notifications import NotificationResponse
from backend.services.apns import InvalidTokenError, send_push
from sqlalchemy import delete, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)


async def register_device(
    db: AsyncSession, user_id: UUID, token: str, platform: str = "ios"
) -> None:
    """Upsert a device token. If token exists for a different user, reassign it."""
    existing = await db.execute(select(DeviceToken).where(DeviceToken.token == token))
    device = existing.scalar_one_or_none()

    if device:
        device.user_id = user_id
        device.platform = platform
    else:
        db.add(DeviceToken(user_id=user_id, token=token, platform=platform))

    await db.flush()


async def unregister_device(db: AsyncSession, user_id: UUID, token: str) -> None:
    """Remove a device token (logout/disable notifications)."""
    await db.execute(
        delete(DeviceToken).where(DeviceToken.user_id == user_id, DeviceToken.token == token)
    )
    await db.flush()


async def create_notification(
    db: AsyncSession,
    recipient_id: UUID,
    notification_type: str,
    title: str,
    body: str,
    actor_id: UUID | None = None,
    target_id: UUID | None = None,
    data: dict | None = None,
) -> Notification:
    """Persist a notification and send push to all registered devices."""
    notification = Notification(
        user_id=recipient_id,
        type=notification_type,
        actor_id=actor_id,
        target_id=target_id,
        data=data,
    )
    db.add(notification)
    await db.flush()

    # Send push to all registered devices
    result = await db.execute(
        select(DeviceToken).where(DeviceToken.user_id == recipient_id)
    )
    devices = result.scalars().all()

    for device in devices:
        try:
            await send_push(device.token, title, body, data)
        except InvalidTokenError:
            logger.info("Removing invalid device token: %s", device.token)
            await db.delete(device)
        except Exception as e:
            logger.error("Failed to send push to %s: %s", device.token, str(e))

    await db.flush()
    return notification


async def get_notifications(
    db: AsyncSession, user_id: UUID, cursor: str | None, limit: int
) -> PaginatedResponse[NotificationResponse]:
    """List notifications for a user with cursor-keyset pagination."""
    stmt = (
        select(Notification)
        .where(Notification.user_id == user_id)
        .order_by(Notification.created_at.desc(), Notification.id.desc())
    )
    stmt = apply_cursor_filter(stmt, Notification, cursor)
    stmt = stmt.limit(limit + 1)

    result = await db.execute(stmt)
    notifications = list(result.scalars().all())

    has_more = len(notifications) > limit
    if has_more:
        notifications = notifications[:limit]

    items = [
        NotificationResponse(
            id=n.id,
            type=n.type,
            actor_id=n.actor_id,
            target_id=n.target_id,
            data=n.data,
            is_read=n.is_read,
            created_at=n.created_at,
        )
        for n in notifications
    ]

    next_cursor = (
        encode_cursor(notifications[-1].created_at, notifications[-1].id)
        if has_more
        else None
    )
    return PaginatedResponse(items=items, next_cursor=next_cursor, has_more=has_more)


async def mark_read(db: AsyncSession, user_id: UUID, notification_ids: list[UUID]) -> int:
    """Bulk mark notifications as read. Returns count of updated rows."""
    if not notification_ids:
        return 0

    result = await db.execute(
        update(Notification)
        .where(Notification.user_id == user_id, Notification.id.in_(notification_ids))
        .values(is_read=True)
    )
    await db.flush()
    return result.rowcount


async def get_unread_count(db: AsyncSession, user_id: UUID) -> int:
    """Badge count: number of unread notifications."""
    result = await db.execute(
        select(func.count(Notification.id)).where(
            Notification.user_id == user_id,
            Notification.is_read == False,  # noqa: E712
        )
    )
    return result.scalar_one()
