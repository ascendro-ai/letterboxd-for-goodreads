"""Pydantic schemas for user profile endpoints."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

__all__ = ["UpdateProfileRequest", "UserBrief", "UserProfile"]


class UpdateProfileRequest(BaseModel):
    username: str | None = Field(None, min_length=3, max_length=20)
    display_name: str | None = Field(None, max_length=100)
    bio: str | None = Field(None, max_length=500)
    avatar_url: str | None = None
    favorite_books: list[UUID] | None = Field(None, max_length=4)


class UserProfile(BaseModel):
    id: UUID
    username: str
    display_name: str | None = None
    avatar_url: str | None = None
    bio: str | None = None
    favorite_books: list[UUID] = []
    books_count: int = 0
    followers_count: int = 0
    following_count: int = 0
    is_following: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}


class UserBrief(BaseModel):
    id: UUID
    username: str
    display_name: str | None = None
    avatar_url: str | None = None

    model_config = {"from_attributes": True}
