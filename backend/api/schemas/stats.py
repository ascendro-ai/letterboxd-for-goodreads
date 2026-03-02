"""Pydantic schemas for reading statistics endpoints."""

from __future__ import annotations

from pydantic import BaseModel

__all__ = ["MonthlyCount", "RatingDistribution", "ReadingStats", "YearlyStats"]


class MonthlyCount(BaseModel):
    month: int  # 1-12
    count: int


class RatingDistribution(BaseModel):
    rating: float  # 0.5, 1.0, ..., 5.0
    count: int


class YearlyStats(BaseModel):
    year: int
    books_read: int
    pages_read: int | None = None
    average_rating: float | None = None
    monthly_breakdown: list[MonthlyCount] = []
    rating_distribution: list[RatingDistribution] = []
    top_genres: list[str] = []


class ReadingStats(BaseModel):
    total_books: int
    total_read: int
    total_reading: int
    total_want_to_read: int
    total_did_not_finish: int
    average_rating: float | None = None
    current_year_stats: YearlyStats | None = None
    yearly_stats: list[YearlyStats] = []
