"""Pipeline-local SQLAlchemy models.

These mirror the backend models but are defined separately so the pipeline
can run independently without importing the backend package.
TODO: unify with backend/models/ once both packages share a common dependency.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import (
    ARRAY,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class Work(Base):
    __tablename__ = "works"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    original_title: Mapped[str | None] = mapped_column(String(500))
    description: Mapped[str | None] = mapped_column(Text)
    first_published_year: Mapped[int | None] = mapped_column(Integer)
    open_library_work_id: Mapped[str | None] = mapped_column(String(50), index=True, unique=True)
    google_books_id: Mapped[str | None] = mapped_column(String(50), index=True)
    subjects: Mapped[list[str] | None] = mapped_column(ARRAY(String))
    cover_image_url: Mapped[str | None] = mapped_column(String(500))
    cover_ol_ids: Mapped[list[str] | None] = mapped_column(ARRAY(String))
    average_rating: Mapped[float | None] = mapped_column(Numeric(3, 2))
    ratings_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    authors: Mapped[list[Author]] = relationship(
        "Author", secondary="work_authors", back_populates="works"
    )
    editions: Mapped[list[Edition]] = relationship("Edition", back_populates="work")


class Author(Base):
    __tablename__ = "authors"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(300), nullable=False)
    bio: Mapped[str | None] = mapped_column(Text)
    photo_url: Mapped[str | None] = mapped_column(String(500))
    open_library_author_id: Mapped[str | None] = mapped_column(
        String(50), index=True, unique=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    works: Mapped[list[Work]] = relationship(
        "Work", secondary="work_authors", back_populates="authors"
    )


class WorkAuthor(Base):
    __tablename__ = "work_authors"

    work_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("works.id"), primary_key=True)
    author_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("authors.id"), primary_key=True)


class Edition(Base):
    __tablename__ = "editions"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    work_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("works.id"), nullable=False)
    isbn_10: Mapped[str | None] = mapped_column(String(20), index=True)
    isbn_13: Mapped[str | None] = mapped_column(String(20), index=True)
    publisher: Mapped[str | None] = mapped_column(String(300))
    publish_date: Mapped[str | None] = mapped_column(String(100))
    page_count: Mapped[int | None] = mapped_column(Integer)
    format: Mapped[str | None] = mapped_column(String(50))
    language: Mapped[str | None] = mapped_column(String(10))
    cover_image_url: Mapped[str | None] = mapped_column(String(500))
    open_library_edition_id: Mapped[str | None] = mapped_column(
        String(50), index=True, unique=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    work: Mapped[Work] = relationship("Work", back_populates="editions")


class TasteMatch(Base):
    __tablename__ = "taste_matches"
    __table_args__ = (UniqueConstraint("user_a_id", "user_b_id"),)

    user_a_id: Mapped[uuid.UUID] = mapped_column(primary_key=True)
    user_b_id: Mapped[uuid.UUID] = mapped_column(primary_key=True)
    match_score: Mapped[float] = mapped_column(Numeric(5, 4), nullable=False)
    overlapping_books_count: Mapped[int] = mapped_column(Integer, nullable=False)
    computed_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class SyncState(Base):
    __tablename__ = "pipeline_sync_state"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    sync_type: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    last_synced_date: Mapped[str | None] = mapped_column(String(20))
    last_synced_offset: Mapped[int] = mapped_column(Integer, default=0)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )
