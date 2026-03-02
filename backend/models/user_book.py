"""User-book interaction models: reading log, shelves, and shelf membership.

UserBook is the core logging unit -- one entry per (user, work) pair. Status
tracks reading progress, while rating uses half-star increments (0.5-5.0)
stored as Numeric(2,1) with a CHECK constraint.

Shelves are user-created collections (max 20 free, unlimited for premium).
ShelfBook is the junction table linking shelves to user_books.
"""

import enum
import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, TimestampMixin, UUIDMixin


class ReadingStatus(enum.Enum):
    READING = "reading"
    READ = "read"
    WANT_TO_READ = "want_to_read"
    DID_NOT_FINISH = "did_not_finish"


class UserBook(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "user_books"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    work_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("works.id", ondelete="CASCADE"), nullable=False
    )
    status: Mapped[ReadingStatus] = mapped_column(nullable=False)
    rating: Mapped[Decimal | None] = mapped_column(Numeric(2, 1))
    review_text: Mapped[str | None] = mapped_column(Text)
    has_spoilers: Mapped[bool] = mapped_column(default=False, server_default="false")
    started_at: Mapped[date | None] = mapped_column()
    finished_at: Mapped[date | None] = mapped_column()
    is_imported: Mapped[bool] = mapped_column(default=False, server_default="false")

    user = relationship("User", lazy="selectin")
    work = relationship("Work", lazy="selectin")

    __table_args__ = (
        UniqueConstraint("user_id", "work_id", name="uq_user_book"),
        CheckConstraint(
            "rating IS NULL OR (rating >= 0.5 AND rating <= 5.0 AND rating * 2 = FLOOR(rating * 2))",
            name="ck_user_books_rating_range",
        ),
    )


class Shelf(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "shelves"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    slug: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    is_public: Mapped[bool] = mapped_column(default=True, server_default="true")
    display_order: Mapped[int] = mapped_column(Integer, default=0, server_default="0")

    user = relationship("User", lazy="selectin")
    shelf_books: Mapped[list["ShelfBook"]] = relationship(
        back_populates="shelf", lazy="selectin", cascade="all, delete-orphan"
    )

    __table_args__ = (
        UniqueConstraint("user_id", "slug", name="uq_shelf_user_slug"),
    )


class ShelfBook(UUIDMixin, Base):
    __tablename__ = "shelf_books"

    shelf_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("shelves.id", ondelete="CASCADE"), nullable=False
    )
    user_book_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("user_books.id", ondelete="CASCADE"), nullable=False
    )
    position: Mapped[int] = mapped_column(Integer, server_default="0")

    shelf: Mapped["Shelf"] = relationship(back_populates="shelf_books")
    user_book = relationship("UserBook", lazy="selectin")

    __table_args__ = (
        UniqueConstraint("shelf_id", "user_book_id", name="uq_shelf_book"),
    )
