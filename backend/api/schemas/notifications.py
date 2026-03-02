"""Pydantic schemas for push notification endpoints."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

__all__ = [
    "RegisterDeviceRequest",
    "UnregisterDeviceRequest",
    "MarkReadRequest",
    "NotificationResponse",
    "UnreadCountResponse",
]


class RegisterDeviceRequest(BaseModel):
    device_token: str = Field(min_length=1, max_length=512)
    platform: str = Field(default="ios", pattern=r"^(ios|android)$")


class UnregisterDeviceRequest(BaseModel):
    device_token: str = Field(min_length=1, max_length=512)


class MarkReadRequest(BaseModel):
    notification_ids: list[UUID]


class NotificationResponse(BaseModel):
    id: UUID
    type: str
    actor_id: UUID | None = None
    target_id: UUID | None = None
    data: dict | None = None
    is_read: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class UnreadCountResponse(BaseModel):
    count: int
