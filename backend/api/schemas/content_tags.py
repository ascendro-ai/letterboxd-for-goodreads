"""Pydantic schemas for content warning and mood tag endpoints."""

from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel

__all__ = ["AvailableTagsResponse", "ContentTagResponse", "VoteTagRequest"]


class VoteTagRequest(BaseModel):
    tag_name: str


class ContentTagResponse(BaseModel):
    id: UUID
    tag_name: str
    tag_type: str  # "content_warning" or "mood"
    vote_count: int
    is_confirmed: bool
    display_name: str

    model_config = {"from_attributes": True}


class AvailableTagsResponse(BaseModel):
    content_warnings: list[str]
    moods: list[str]
