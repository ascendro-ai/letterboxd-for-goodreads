from __future__ import annotations

from uuid import UUID

from backend.api.schemas.user_books import UserBookResponse
from pydantic import BaseModel, Field

__all__ = [
    "AddBookToShelfRequest",
    "CreateShelfRequest",
    "ShelfDetailResponse",
    "ShelfResponse",
    "UpdateShelfRequest",
]


class CreateShelfRequest(BaseModel):
    name: str = Field(max_length=100)
    description: str | None = None
    is_public: bool = True


class UpdateShelfRequest(BaseModel):
    name: str | None = Field(None, max_length=100)
    description: str | None = None
    is_public: bool | None = None
    display_order: int | None = None


class AddBookToShelfRequest(BaseModel):
    user_book_id: UUID


class ShelfResponse(BaseModel):
    id: UUID
    name: str
    slug: str
    description: str | None = None
    is_public: bool = True
    display_order: int = 0
    book_count: int = 0

    model_config = {"from_attributes": True}


class ShelfDetailResponse(ShelfResponse):
    books: list[UserBookResponse] = []
