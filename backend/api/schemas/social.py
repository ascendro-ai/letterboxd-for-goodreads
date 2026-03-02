"""Pydantic schemas for social graph endpoints."""

from decimal import Decimal

from backend.api.schemas.users import UserBrief
from pydantic import BaseModel

__all__ = ["TasteMatchResponse"]


class TasteMatchResponse(BaseModel):
    user: UserBrief
    match_score: Decimal
    overlapping_books_count: int

    model_config = {"from_attributes": True}
