from __future__ import annotations

from typing import Generic, TypeVar

from pydantic import BaseModel

T = TypeVar("T")

__all__ = ["ErrorDetail", "ErrorResponse", "PaginatedResponse"]


class PaginatedResponse(BaseModel, Generic[T]):  # noqa: UP046
    items: list[T]
    next_cursor: str | None = None
    has_more: bool = False


class ErrorDetail(BaseModel):
    code: str
    message: str


class ErrorResponse(BaseModel):
    error: ErrorDetail
