import enum
import uuid
from decimal import Decimal

from sqlalchemy import (
    Column,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Table,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, PgArray, TimestampMixin, UUIDMixin

work_authors = Table(
    "work_authors",
    Base.metadata,
    Column("work_id", ForeignKey("works.id", ondelete="CASCADE"), primary_key=True),
    Column(
        "author_id", ForeignKey("authors.id", ondelete="CASCADE"), primary_key=True
    ),
)


class Work(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "works"

    title: Mapped[str] = mapped_column(String(500), nullable=False)
    original_title: Mapped[str | None] = mapped_column(String(500))
    description: Mapped[str | None] = mapped_column(Text)
    first_published_year: Mapped[int | None] = mapped_column(Integer)
    open_library_work_id: Mapped[str | None] = mapped_column(
        String(50), index=True, unique=True
    )
    google_books_id: Mapped[str | None] = mapped_column(
        String(50), index=True, unique=True
    )
    subjects: Mapped[list[str] | None] = mapped_column(PgArray(String))
    cover_image_url: Mapped[str | None] = mapped_column(String(500))
    average_rating: Mapped[Decimal | None] = mapped_column(Numeric(3, 2))
    ratings_count: Mapped[int] = mapped_column(Integer, server_default="0")

    authors: Mapped[list["Author"]] = relationship(
        secondary=work_authors, back_populates="works", lazy="selectin"
    )
    editions: Mapped[list["Edition"]] = relationship(
        back_populates="work", lazy="selectin"
    )

    __table_args__ = (
        Index("ix_works_title_trgm", "title", postgresql_using="gin",
              postgresql_ops={"title": "gin_trgm_ops"}),
    )


class EditionFormat(enum.Enum):
    HARDCOVER = "hardcover"
    PAPERBACK = "paperback"
    EBOOK = "ebook"
    AUDIOBOOK = "audiobook"


class Edition(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "editions"

    work_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("works.id", ondelete="CASCADE"), nullable=False
    )
    isbn_10: Mapped[str | None] = mapped_column(String(10), index=True)
    isbn_13: Mapped[str | None] = mapped_column(String(13), index=True)
    publisher: Mapped[str | None] = mapped_column(String(300))
    publish_date: Mapped[str | None] = mapped_column(String(50))
    page_count: Mapped[int | None] = mapped_column(Integer)
    format: Mapped[EditionFormat | None] = mapped_column()
    language: Mapped[str | None] = mapped_column(String(10))
    cover_image_url: Mapped[str | None] = mapped_column(String(500))
    open_library_edition_id: Mapped[str | None] = mapped_column(
        String(50), index=True, unique=True
    )

    work: Mapped["Work"] = relationship(back_populates="editions")


class Author(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "authors"

    name: Mapped[str] = mapped_column(String(300), nullable=False)
    bio: Mapped[str | None] = mapped_column(Text)
    photo_url: Mapped[str | None] = mapped_column(String(500))
    open_library_author_id: Mapped[str | None] = mapped_column(
        String(50), index=True, unique=True
    )

    works: Mapped[list["Work"]] = relationship(
        secondary=work_authors, back_populates="authors", lazy="selectin"
    )

    __table_args__ = (
        Index("ix_authors_name_trgm", "name", postgresql_using="gin",
              postgresql_ops={"name": "gin_trgm_ops"}),
    )
