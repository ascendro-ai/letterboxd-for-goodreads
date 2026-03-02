"""
Stub models for the API layer.

LIMITATION: This entire file is a temporary stub. The real models live in
backend/models/ on the backend/database branch. When that branch merges to main:
  1. Replace all imports across api/ and services/ with real model imports:
       from backend.models.work import Work, Edition, Author, WorkAuthor
       from backend.models.user import User
       from backend.models.user_book import UserBook, Shelf, ShelfBook
       from backend.models.social import Follow, Block, Mute, Activity
       from backend.models.taste_match import TasteMatch
  2. Delete this file entirely.
  3. Remove the StringUUID TypeDecorator (Postgres uses native UUID columns).
  4. Remove the TESTING/SQLite branching logic (tests should use a real Postgres instance
     or testcontainers for full fidelity).
"""

import os
import uuid
from datetime import datetime
from decimal import Decimal
from typing import List, Optional

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    func,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship
from sqlalchemy.types import TypeDecorator

# Use JSON instead of ARRAY/JSONB when testing with SQLite
TESTING = os.environ.get("TESTING", "0") == "1"

if TESTING:
    from sqlalchemy import JSON

    ARRAY_TYPE = JSON
    JSONB_TYPE = JSON
    UUID_TYPE = String(36)
else:
    from sqlalchemy.dialects.postgresql import ARRAY, JSONB
    from sqlalchemy.dialects.postgresql import UUID as PG_UUID

    ARRAY_TYPE = None  # sentinel — use ARRAY(String) directly
    JSONB_TYPE = JSONB
    UUID_TYPE = PG_UUID(as_uuid=True)


class StringUUID(TypeDecorator):
    """TypeDecorator that stores UUIDs as String(36) and converts UUID objects to strings.

    Used in SQLite test mode so that WHERE comparisons with uuid.UUID objects work correctly.
    """

    impl = String(36)
    cache_ok = True

    def process_bind_param(self, value, dialect):
        if value is not None:
            return str(value)
        return value

    def process_result_value(self, value, dialect):
        return value


def _str_uuid():
    """Generate a string UUID for SQLite compatibility."""
    return str(uuid.uuid4())


def _uuid_col(primary_key: bool = False, default: bool = True, **kwargs):
    """Helper to build a UUID column that works in both Postgres and SQLite test mode."""
    kw = {"primary_key": primary_key, **kwargs}
    if TESTING:
        if default:
            kw["default"] = _str_uuid
        return mapped_column(StringUUID(), **kw)
    if default:
        kw["default"] = uuid.uuid4
    return mapped_column(PG_UUID(as_uuid=True), **kw)


def _array_string_col(**kwargs):
    if TESTING:
        return mapped_column(JSON, **kwargs)
    return mapped_column(ARRAY(String), **kwargs)


def _array_uuid_col(**kwargs):
    if TESTING:
        return mapped_column(JSON, **kwargs)
    return mapped_column(ARRAY(PG_UUID(as_uuid=True)), **kwargs)


def _jsonb_col(**kwargs):
    if TESTING:
        return mapped_column(JSON, **kwargs)
    return mapped_column(JSONB, **kwargs)


def _fk_uuid_col(fk: str, **kwargs):
    # Pop 'default' to prevent it from being interpreted as a literal column default.
    # default=False was used to match _uuid_col's interface but FK columns don't need UUID auto-gen.
    kwargs.pop("default", None)
    if TESTING:
        return mapped_column(StringUUID(), ForeignKey(fk), **kwargs)
    return mapped_column(PG_UUID(as_uuid=True), ForeignKey(fk), **kwargs)


class Base(DeclarativeBase):
    pass


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


# --- Book domain ---


class Work(TimestampMixin, Base):
    __tablename__ = "works"

    id: Mapped[uuid.UUID] = _uuid_col(primary_key=True)
    title: Mapped[str] = mapped_column(String(500))
    original_title: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    first_published_year: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    open_library_work_id: Mapped[Optional[str]] = mapped_column(
        String(50), index=True, nullable=True
    )
    google_books_id: Mapped[Optional[str]] = mapped_column(String(50), index=True, nullable=True)
    subjects: Mapped[Optional[List[str]]] = _array_string_col(nullable=True)
    cover_image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    average_rating: Mapped[Optional[Decimal]] = mapped_column(Numeric(3, 2), nullable=True)
    ratings_count: Mapped[int] = mapped_column(Integer, default=0)

    authors: Mapped[List["Author"]] = relationship(
        secondary="work_authors", back_populates="works", lazy="selectin"
    )
    editions: Mapped[List["Edition"]] = relationship(back_populates="work", lazy="selectin")


class Edition(TimestampMixin, Base):
    __tablename__ = "editions"

    id: Mapped[uuid.UUID] = _uuid_col(primary_key=True)
    work_id: Mapped[uuid.UUID] = _fk_uuid_col("works.id", index=True)
    isbn_10: Mapped[Optional[str]] = mapped_column(String(13), index=True, nullable=True)
    isbn_13: Mapped[Optional[str]] = mapped_column(String(17), index=True, nullable=True)
    publisher: Mapped[Optional[str]] = mapped_column(String(300), nullable=True)
    publish_date: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    page_count: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    format: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    language: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)
    cover_image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    open_library_edition_id: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    work: Mapped["Work"] = relationship(back_populates="editions")


class Author(Base):
    __tablename__ = "authors"

    id: Mapped[uuid.UUID] = _uuid_col(primary_key=True)
    name: Mapped[str] = mapped_column(String(300))
    bio: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    photo_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    open_library_author_id: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    works: Mapped[List["Work"]] = relationship(
        secondary="work_authors", back_populates="authors", lazy="selectin"
    )


class WorkAuthor(Base):
    __tablename__ = "work_authors"

    work_id: Mapped[uuid.UUID] = _fk_uuid_col("works.id", primary_key=True, default=False)
    author_id: Mapped[uuid.UUID] = _fk_uuid_col("authors.id", primary_key=True, default=False)


# --- User domain ---


class User(TimestampMixin, Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = _uuid_col(primary_key=True, default=False)
    username: Mapped[str] = mapped_column(String(30), unique=True)
    display_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    avatar_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    bio: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    favorite_books: Mapped[Optional[List[uuid.UUID]]] = _array_uuid_col(nullable=True)
    is_premium: Mapped[bool] = mapped_column(Boolean, default=False)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)


# --- User book domain ---


class UserBook(TimestampMixin, Base):
    __tablename__ = "user_books"

    id: Mapped[uuid.UUID] = _uuid_col(primary_key=True)
    user_id: Mapped[uuid.UUID] = _fk_uuid_col("users.id", index=True)
    work_id: Mapped[uuid.UUID] = _fk_uuid_col("works.id", index=True)
    status: Mapped[str] = mapped_column(String(20))
    rating: Mapped[Optional[Decimal]] = mapped_column(Numeric(2, 1), nullable=True)
    review_text: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    has_spoilers: Mapped[bool] = mapped_column(Boolean, default=False)
    started_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    finished_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    is_imported: Mapped[bool] = mapped_column(Boolean, default=False)
    is_hidden: Mapped[bool] = mapped_column(Boolean, default=False)

    user: Mapped["User"] = relationship(lazy="selectin")
    work: Mapped["Work"] = relationship(lazy="selectin")


class Shelf(TimestampMixin, Base):
    __tablename__ = "shelves"

    id: Mapped[uuid.UUID] = _uuid_col(primary_key=True)
    user_id: Mapped[uuid.UUID] = _fk_uuid_col("users.id", index=True)
    name: Mapped[str] = mapped_column(String(100))
    slug: Mapped[str] = mapped_column(String(100))
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    is_public: Mapped[bool] = mapped_column(Boolean, default=True)
    display_order: Mapped[int] = mapped_column(Integer, default=0)


class ShelfBook(Base):
    __tablename__ = "shelf_books"

    shelf_id: Mapped[uuid.UUID] = _fk_uuid_col("shelves.id", primary_key=True, default=False)
    user_book_id: Mapped[uuid.UUID] = _fk_uuid_col("user_books.id", primary_key=True, default=False)
    position: Mapped[int] = mapped_column(Integer, default=0)


# --- Social domain ---


class Follow(Base):
    __tablename__ = "follows"

    follower_id: Mapped[uuid.UUID] = _fk_uuid_col("users.id", primary_key=True, default=False)
    following_id: Mapped[uuid.UUID] = _fk_uuid_col("users.id", primary_key=True, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Block(Base):
    __tablename__ = "blocks"

    blocker_id: Mapped[uuid.UUID] = _fk_uuid_col("users.id", primary_key=True, default=False)
    blocked_id: Mapped[uuid.UUID] = _fk_uuid_col("users.id", primary_key=True, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Mute(Base):
    __tablename__ = "mutes"

    muter_id: Mapped[uuid.UUID] = _fk_uuid_col("users.id", primary_key=True, default=False)
    muted_id: Mapped[uuid.UUID] = _fk_uuid_col("users.id", primary_key=True, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Activity(Base):
    __tablename__ = "activities"

    id: Mapped[uuid.UUID] = _uuid_col(primary_key=True)
    user_id: Mapped[uuid.UUID] = _fk_uuid_col("users.id", index=True)
    activity_type: Mapped[str] = mapped_column(String(30))
    target_id: Mapped[uuid.UUID] = _uuid_col(default=False)
    metadata_: Mapped[Optional[dict]] = _jsonb_col(nullable=True, key="metadata")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class TasteMatch(Base):
    __tablename__ = "taste_matches"

    user_a_id: Mapped[uuid.UUID] = _fk_uuid_col("users.id", primary_key=True, default=False)
    user_b_id: Mapped[uuid.UUID] = _fk_uuid_col("users.id", primary_key=True, default=False)
    match_score: Mapped[Decimal] = mapped_column(Numeric(4, 3))
    overlapping_books_count: Mapped[int] = mapped_column(Integer)
    computed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[uuid.UUID] = _uuid_col(primary_key=True)
    user_id: Mapped[uuid.UUID] = _fk_uuid_col("users.id", index=True)
    type: Mapped[str] = mapped_column(String(30))
    actor_id: Mapped[Optional[uuid.UUID]] = _fk_uuid_col("users.id", nullable=True, default=False)
    target_id: Mapped[Optional[uuid.UUID]] = _uuid_col(nullable=True, default=False)
    data: Mapped[Optional[dict]] = _jsonb_col(nullable=True)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ImportJob(Base):
    __tablename__ = "import_jobs"

    id: Mapped[uuid.UUID] = _uuid_col(primary_key=True)
    user_id: Mapped[uuid.UUID] = _fk_uuid_col("users.id", index=True)
    source: Mapped[str] = mapped_column(String(20))
    status: Mapped[str] = mapped_column(String(20), default="pending")
    total_books: Mapped[int] = mapped_column(Integer, default=0)
    matched: Mapped[int] = mapped_column(Integer, default=0)
    needs_review: Mapped[int] = mapped_column(Integer, default=0)
    unmatched: Mapped[int] = mapped_column(Integer, default=0)
    progress_percent: Mapped[int] = mapped_column(Integer, default=0)
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)


# --- Content moderation domain ---
# TODO: provided by backend/database — ReviewFlag model


class ReviewFlag(TimestampMixin, Base):
    __tablename__ = "review_flags"

    id: Mapped[uuid.UUID] = _uuid_col(primary_key=True)
    flagger_user_id: Mapped[uuid.UUID] = _fk_uuid_col("users.id", index=True)
    user_book_id: Mapped[uuid.UUID] = _fk_uuid_col("user_books.id", index=True)
    reason: Mapped[str] = mapped_column(String(20))
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="pending")
    reviewed_by: Mapped[Optional[uuid.UUID]] = _fk_uuid_col(
        "users.id", nullable=True, default=False
    )
    resolved_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)


# --- Metadata reporting domain ---
# TODO: provided by backend/database — MetadataReport model


class MetadataReport(TimestampMixin, Base):
    __tablename__ = "metadata_reports"

    id: Mapped[uuid.UUID] = _uuid_col(primary_key=True)
    reporter_user_id: Mapped[uuid.UUID] = _fk_uuid_col("users.id", index=True)
    work_id: Mapped[uuid.UUID] = _fk_uuid_col("works.id", index=True)
    issue_type: Mapped[str] = mapped_column(String(30))
    description: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(20), default="OPEN")
    reviewed_by: Mapped[Optional[uuid.UUID]] = _fk_uuid_col(
        "users.id", nullable=True, default=False
    )
    resolved_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)


# --- Waitlist & invite codes domain ---
# TODO: provided by backend/database — Waitlist and InviteCode models


class Waitlist(TimestampMixin, Base):
    __tablename__ = "waitlist"

    id: Mapped[uuid.UUID] = _uuid_col(primary_key=True)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    invited_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    invite_code_id: Mapped[Optional[uuid.UUID]] = _fk_uuid_col(
        "invite_codes.id", nullable=True, default=False
    )


class InviteCode(TimestampMixin, Base):
    __tablename__ = "invite_codes"

    id: Mapped[uuid.UUID] = _uuid_col(primary_key=True)
    code: Mapped[str] = mapped_column(String(12), unique=True, index=True)
    created_by_user_id: Mapped[Optional[uuid.UUID]] = _fk_uuid_col(
        "users.id", nullable=True, default=False
    )
    claimed_by_user_id: Mapped[Optional[uuid.UUID]] = _fk_uuid_col(
        "users.id", nullable=True, default=False
    )
    claimed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)


# --- Data export domain ---
# TODO: provided by backend/database — ExportRequest model


class ExportRequest(TimestampMixin, Base):
    __tablename__ = "export_requests"

    id: Mapped[uuid.UUID] = _uuid_col(primary_key=True)
    user_id: Mapped[uuid.UUID] = _fk_uuid_col("users.id", index=True)
    status: Mapped[str] = mapped_column(String(20), default="pending")
    file_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    file_size_bytes: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)


# --- Friend discovery domain ---
# TODO: provided by backend/database — UserContactHash model


class UserContactHash(TimestampMixin, Base):
    __tablename__ = "user_contact_hashes"

    id: Mapped[uuid.UUID] = _uuid_col(primary_key=True)
    user_id: Mapped[uuid.UUID] = _fk_uuid_col("users.id", index=True)
    hash: Mapped[str] = mapped_column(String(64))
    hash_type: Mapped[str] = mapped_column(String(10))
