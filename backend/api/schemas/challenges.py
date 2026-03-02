"""Schemas for reading challenge endpoints."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class CreateChallengeRequest(BaseModel):
    year: int = Field(..., ge=2020, le=2100)
    goal_count: int = Field(..., ge=1, le=500)


class UpdateChallengeRequest(BaseModel):
    goal_count: int = Field(..., ge=1, le=500)


class ChallengeBookItem(BaseModel):
    user_book_id: UUID
    work_title: str
    authors: list[str]
    cover_image_url: str | None = None
    finished_at: datetime | None = None


class ChallengeResponse(BaseModel):
    id: UUID
    year: int
    goal_count: int
    current_count: int
    is_complete: bool
    completed_at: datetime | None = None
    created_at: datetime
    books: list[ChallengeBookItem] | None = None

    model_config = {"from_attributes": True}
