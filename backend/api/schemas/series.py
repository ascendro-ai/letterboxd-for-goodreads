"""Schemas for book series endpoints."""

from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel


class SeriesWorkItem(BaseModel):
    position: float
    is_main_entry: bool
    work_id: UUID
    title: str
    authors: list[str]
    cover_image_url: str | None = None
    user_status: str | None = None

    model_config = {"from_attributes": True}


class SeriesResponse(BaseModel):
    id: UUID
    name: str
    description: str | None = None
    total_books: int | None = None
    is_complete: bool
    cover_image_url: str | None = None
    works: list[SeriesWorkItem]

    model_config = {"from_attributes": True}


class SeriesProgressResponse(BaseModel):
    series_id: UUID
    series_name: str
    total_main_entries: int
    read_count: int
    reading_count: int
    progress_percent: float
