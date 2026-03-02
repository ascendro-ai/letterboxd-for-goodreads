"""Pydantic schemas for CSV import endpoints."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel

__all__ = ["ImportStatusResponse"]


class ImportStatusResponse(BaseModel):
    id: UUID
    source: str
    status: str
    total_books: int = 0
    matched: int = 0
    needs_review: int = 0
    unmatched: int = 0
    progress_percent: int = 0
    error_message: str | None = None
    created_at: datetime
    completed_at: datetime | None = None

    model_config = {"from_attributes": True}
