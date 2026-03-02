"""Pydantic schemas for activity feed and notification endpoints."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from backend.api.schemas.books import BookBrief
from backend.api.schemas.users import UserBrief
from pydantic import BaseModel

__all__ = ["FeedItem", "FeedResponse", "MarkReadRequest", "NotificationItem"]


class FeedItem(BaseModel):
    id: UUID
    user: UserBrief
    activity_type: str
    book: BookBrief
    rating: Decimal | None = None
    review_text: str | None = None
    has_spoilers: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}


class FeedResponse(BaseModel):
    """Feed response with feed type metadata for cold start detection."""

    items: list[FeedItem]
    next_cursor: str | None = None
    has_more: bool = False
    feed_type: str = "following"

    model_config = {"from_attributes": True}


class NotificationItem(BaseModel):
    id: UUID
    type: str
    actor: UserBrief | None = None
    data: dict | None = None
    is_read: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}


class MarkReadRequest(BaseModel):
    notification_ids: list[UUID]
