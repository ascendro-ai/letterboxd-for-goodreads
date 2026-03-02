from __future__ import annotations

from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel

__all__ = ["AuthorBrief", "BookBrief", "BookDetail", "BookSearchResult"]


class AuthorBrief(BaseModel):
    id: UUID
    name: str

    model_config = {"from_attributes": True}


class BookDetail(BaseModel):
    id: UUID
    title: str
    original_title: str | None = None
    description: str | None = None
    first_published_year: int | None = None
    authors: list[AuthorBrief] = []
    subjects: list[str] = []
    cover_image_url: str | None = None
    average_rating: Decimal | None = None
    ratings_count: int = 0
    editions_count: int = 0
    bookshop_url: str | None = None

    model_config = {"from_attributes": True}


class BookBrief(BaseModel):
    id: UUID
    title: str
    authors: list[AuthorBrief] = []
    cover_image_url: str | None = None
    average_rating: Decimal | None = None
    ratings_count: int = 0

    model_config = {"from_attributes": True}


class BookSearchResult(BaseModel):
    id: UUID
    title: str
    authors: list[AuthorBrief] = []
    cover_image_url: str | None = None
    first_published_year: int | None = None

    model_config = {"from_attributes": True}
