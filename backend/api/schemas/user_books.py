"""Pydantic schemas for reading log endpoints."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from backend.api.schemas.books import BookBrief
from pydantic import BaseModel, Field, field_validator

__all__ = ["LogBookRequest", "UpdateBookRequest", "UserBookResponse"]


class LogBookRequest(BaseModel):
    work_id: UUID
    status: str = Field(pattern=r"^(reading|read|want_to_read|did_not_finish)$")
    rating: Decimal | None = Field(None, ge=0.5, le=5.0)
    review_text: str | None = None
    has_spoilers: bool = False
    started_at: datetime | None = None
    finished_at: datetime | None = None

    @field_validator("rating")
    @classmethod
    def validate_half_star(cls, v: Decimal | None) -> Decimal | None:
        if v is not None and v % Decimal("0.5") != 0:
            raise ValueError("Rating must be in 0.5 increments")
        return v


class UpdateBookRequest(BaseModel):
    status: str | None = Field(None, pattern=r"^(reading|read|want_to_read|did_not_finish)$")
    rating: Decimal | None = Field(None, ge=0.5, le=5.0)
    review_text: str | None = None
    has_spoilers: bool | None = None
    started_at: datetime | None = None
    finished_at: datetime | None = None

    @field_validator("rating")
    @classmethod
    def validate_half_star(cls, v: Decimal | None) -> Decimal | None:
        if v is not None and v % Decimal("0.5") != 0:
            raise ValueError("Rating must be in 0.5 increments")
        return v


class UserBookResponse(BaseModel):
    id: UUID
    work_id: UUID
    status: str
    rating: Decimal | None = None
    review_text: str | None = None
    has_spoilers: bool = False
    started_at: datetime | None = None
    finished_at: datetime | None = None
    is_imported: bool = False
    created_at: datetime
    updated_at: datetime
    book: BookBrief | None = None

    model_config = {"from_attributes": True}
