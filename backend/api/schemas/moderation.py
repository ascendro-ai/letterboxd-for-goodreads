from __future__ import annotations

import enum
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

__all__ = [
    "FlagReviewRequest",
    "FlagReviewResponse",
    "ModerationResult",
]


class FlagReasonSchema(str, enum.Enum):
    SPAM = "spam"
    HARASSMENT = "harassment"
    SPOILERS = "spoilers"
    HATE_SPEECH = "hate_speech"
    OTHER = "other"


class FlagReviewRequest(BaseModel):
    reason: FlagReasonSchema
    description: str | None = Field(None, max_length=500)


class FlagReviewResponse(BaseModel):
    id: UUID
    reason: str
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class ModerationResult(BaseModel):
    """Internal model returned by the moderation check — not exposed to clients."""

    is_flagged: bool
    is_borderline: bool = False
    categories: list[str]
    confidence: float
