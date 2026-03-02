import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import ForeignKey, Integer, Numeric
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base


class TasteMatch(Base):
    __tablename__ = "taste_matches"

    user_a_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    user_b_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    match_score: Mapped[Decimal] = mapped_column(
        Numeric(4, 3), nullable=False
    )
    overlapping_books_count: Mapped[int] = mapped_column(
        Integer, nullable=False
    )
    computed_at: Mapped[datetime] = mapped_column(nullable=False)
