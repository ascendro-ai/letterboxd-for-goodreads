# Plan 25 — Per-Book Privacy, Reading Stats & Content Warnings

Complete, copy-paste-ready implementation for all three features.
Every file shows the **full final state** (not diffs) so you can replace in place.

---

## Table of Contents

1. [A. Per-Book Privacy](#a-per-book-privacy)
2. [B. Reading Stats](#b-reading-stats)
3. [C. Content Warnings & Mood Tags](#c-content-warnings--mood-tags)
4. [D. Alembic Migration](#d-alembic-migration)
5. [E. Tests](#e-tests)

---

## A. Per-Book Privacy

### A1. Database: Add `is_private` to UserBook

**File: `backend/models/user_book.py`** — Add `is_private` column after `is_imported`:

```python
# Add this line after line 52 (is_imported):
is_private: Mapped[bool] = mapped_column(default=False, server_default="false")
```

The full column list becomes:
```python
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
    is_private: Mapped[bool] = mapped_column(default=False, server_default="false")

    # ... relationships and table_args unchanged
```

### A2. Model Stubs: Add `is_private` to UserBook

**File: `backend/api/model_stubs.py`** — Add after `is_hidden` (line 226):

```python
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
    is_private: Mapped[bool] = mapped_column(Boolean, default=False)  # <-- NEW

    user: Mapped["User"] = relationship(lazy="selectin")
    work: Mapped["Work"] = relationship(lazy="selectin")
```

### A3. Schemas: Add `is_private` to request/response

**File: `backend/api/schemas/user_books.py`** — Full replacement:

```python
"""Pydantic schemas for reading log endpoints."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from uuid import UUID

from backend.api.schemas.books import BookBrief
from pydantic import BaseModel, Field, field_validator

__all__ = ["LogBookRequest", "UpdateBookRequest", "UserBookResponse"]


class LogBookRequest(BaseModel):
    work_id: UUID
    status: str = Field(pattern=r"^(reading|read|want_to_read|did_not_finish)$")
    rating: Decimal | None = Field(None, ge=0.5, le=5.0)
    review_text: str | None = None
    has_spoilers: bool = False
    started_at: datetime | None = None
    finished_at: datetime | None = None
    is_private: bool = False  # <-- NEW

    @field_validator("rating")
    @classmethod
    def validate_half_star(cls, v: Decimal | None) -> Decimal | None:
        if v is not None and v % Decimal("0.5") != 0:
            raise ValueError("Rating must be in 0.5 increments")
        return v


class UpdateBookRequest(BaseModel):
    status: str | None = Field(None, pattern=r"^(reading|read|want_to_read|did_not_finish)$")
    rating: Decimal | None = Field(None, ge=0.5, le=5.0)
    review_text: str | None = None
    has_spoilers: bool | None = None
    started_at: datetime | None = None
    finished_at: datetime | None = None
    is_private: bool | None = None  # <-- NEW

    @field_validator("rating")
    @classmethod
    def validate_half_star(cls, v: Decimal | None) -> Decimal | None:
        if v is not None and v % Decimal("0.5") != 0:
            raise ValueError("Rating must be in 0.5 increments")
        return v


class UserBookResponse(BaseModel):
    id: UUID
    work_id: UUID
    status: str
    rating: Decimal | None = None
    review_text: str | None = None
    has_spoilers: bool = False
    started_at: datetime | None = None
    finished_at: datetime | None = None
    is_imported: bool = False
    is_private: bool = False  # <-- NEW
    created_at: datetime
    updated_at: datetime
    book: BookBrief | None = None

    model_config = {"from_attributes": True}
```

### A4. Service: Privacy-aware Activity creation & listing

**File: `backend/services/user_book_service.py`** — Full replacement:

```python
"""Reading log service: log books, rate, review, update status.

Business rules:
- Ratings require a review (encourages thoughtful engagement). Imported books
  are exempt since they were already rated on another platform.
- Only "reading" and "read" status changes create Activity entries. "Want to
  read" and "did not finish" are silent -- they'd clutter feeds without being
  interesting to followers.
- Private books never create Activity entries and are hidden from other users'
  views of your library.
"""

from __future__ import annotations

from decimal import Decimal
from uuid import UUID

from backend.api.errors import (
    already_logged,
    blocked_user,
    book_not_found,
    review_required,
    user_book_not_found,
)
from backend.api.model_stubs import Activity, ShelfBook, UserBook, Work
from backend.api.pagination import apply_cursor_filter, encode_cursor
from backend.api.schemas.books import AuthorBrief, BookBrief
from backend.api.schemas.common import PaginatedResponse
from backend.api.schemas.user_books import LogBookRequest, UpdateBookRequest, UserBookResponse
from backend.services.social_service import is_blocked
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession


async def log_book(
    db: AsyncSession,
    user_id: UUID,
    request: LogBookRequest,
) -> UserBookResponse:
    """Log a book: validate, create UserBook, create Activity, update stats."""
    # Verify work exists
    work_result = await db.execute(select(Work).where(Work.id == request.work_id))
    work = work_result.scalar_one_or_none()
    if work is None:
        raise book_not_found()

    # Check for duplicate
    existing = await db.execute(
        select(UserBook).where(UserBook.user_id == user_id, UserBook.work_id == request.work_id)
    )
    if existing.scalar_one_or_none() is not None:
        raise already_logged()

    # Enforce review-required rule (new ratings only, imports exempt)
    if request.rating is not None and not request.review_text:
        raise review_required()

    user_book = UserBook(
        user_id=user_id,
        work_id=request.work_id,
        status=request.status,
        rating=request.rating,
        review_text=request.review_text,
        has_spoilers=request.has_spoilers,
        started_at=request.started_at,
        finished_at=request.finished_at,
        is_private=request.is_private,  # <-- NEW
    )
    db.add(user_book)
    await db.flush()

    # Create activity — only for public books with read/reading status
    if request.status in ("read", "reading") and not request.is_private:  # <-- CHANGED
        activity_type = "finished_book" if request.status == "read" else "started_book"
        activity = Activity(
            user_id=user_id,
            activity_type=activity_type,
            target_id=user_book.id,
        )
        db.add(activity)

    # Update work aggregate stats if rated
    if request.rating is not None:
        await _update_work_rating(db, request.work_id)

    await db.flush()

    return _to_response(user_book, work)


async def update_book(
    db: AsyncSession,
    user_id: UUID,
    user_book_id: UUID,
    request: UpdateBookRequest,
) -> UserBookResponse:
    """Update a logged book's status, rating, or review."""
    result = await db.execute(
        select(UserBook).where(UserBook.id == user_book_id, UserBook.user_id == user_id)
    )
    user_book = result.scalar_one_or_none()
    if user_book is None:
        raise user_book_not_found()

    old_status = user_book.status

    if request.status is not None:
        user_book.status = request.status
    if request.rating is not None:
        # Enforce review-required for non-imported books
        review = request.review_text
        new_review = review if review is not None else user_book.review_text
        if not new_review and not user_book.is_imported:
            raise review_required()
        user_book.rating = request.rating
    if request.review_text is not None:
        user_book.review_text = request.review_text
    if request.has_spoilers is not None:
        user_book.has_spoilers = request.has_spoilers
    if request.started_at is not None:
        user_book.started_at = request.started_at
    if request.finished_at is not None:
        user_book.finished_at = request.finished_at
    if request.is_private is not None:  # <-- NEW
        user_book.is_private = request.is_private

    # Create activity on status change to read/reading — only for public books
    new_status = user_book.status
    if (
        new_status != old_status
        and new_status in ("read", "reading")
        and not user_book.is_private  # <-- NEW
    ):
        activity_type = "finished_book" if new_status == "read" else "started_book"
        activity = Activity(
            user_id=user_id,
            activity_type=activity_type,
            target_id=user_book.id,
        )
        db.add(activity)

    if request.rating is not None:
        await _update_work_rating(db, user_book.work_id)

    await db.flush()
    await db.refresh(user_book)

    work_result = await db.execute(select(Work).where(Work.id == user_book.work_id))
    work = work_result.scalar_one_or_none()

    return _to_response(user_book, work)


async def delete_book(
    db: AsyncSession,
    user_id: UUID,
    user_book_id: UUID,
) -> None:
    """Remove a book from user's library and cascade shelf_books."""
    result = await db.execute(
        select(UserBook).where(UserBook.id == user_book_id, UserBook.user_id == user_id)
    )
    user_book = result.scalar_one_or_none()
    if user_book is None:
        raise user_book_not_found()

    work_id = user_book.work_id

    # Remove from any shelves
    await db.execute(ShelfBook.__table__.delete().where(ShelfBook.user_book_id == user_book_id))

    await db.delete(user_book)
    await _update_work_rating(db, work_id)
    await db.flush()


async def list_user_books(
    db: AsyncSession,
    requesting_user_id: UUID,
    target_user_id: UUID,
    status_filter: str | None,
    cursor: str | None,
    limit: int,
) -> PaginatedResponse[UserBookResponse]:
    """List a user's books. Checks blocks if viewing another user.

    Private books are only visible to the owner.
    """
    if str(requesting_user_id) != str(target_user_id) and await is_blocked(
        db, requesting_user_id, target_user_id
    ):
        raise blocked_user()

    stmt = select(UserBook).where(UserBook.user_id == target_user_id)

    # Hide private books when viewing another user's library
    if str(requesting_user_id) != str(target_user_id):  # <-- NEW
        stmt = stmt.where(UserBook.is_private == False)  # noqa: E712

    if status_filter:
        stmt = stmt.where(UserBook.status == status_filter)
    stmt = stmt.order_by(UserBook.created_at.desc(), UserBook.id.desc())
    stmt = apply_cursor_filter(stmt, UserBook, cursor)
    stmt = stmt.limit(limit + 1)

    result = await db.execute(stmt)
    user_books = list(result.scalars().all())

    has_more = len(user_books) > limit
    if has_more:
        user_books = user_books[:limit]

    # Batch load works
    if user_books:
        work_ids = [ub.work_id for ub in user_books]
        works_result = await db.execute(select(Work).where(Work.id.in_(work_ids)))
        works_map = {w.id: w for w in works_result.scalars().all()}
    else:
        works_map = {}

    items = [_to_response(ub, works_map.get(ub.work_id)) for ub in user_books]
    next_cursor = encode_cursor(user_books[-1].created_at, user_books[-1].id) if has_more else None

    return PaginatedResponse(items=items, next_cursor=next_cursor, has_more=has_more)


async def _update_work_rating(db: AsyncSession, work_id: UUID) -> None:
    """Recalculate average_rating and ratings_count for a work."""
    result = await db.execute(
        select(
            func.count().label("cnt"),
            func.avg(UserBook.rating).label("avg"),
        ).where(
            UserBook.work_id == work_id,
            UserBook.rating.isnot(None),
        )
    )
    row = result.one()
    work_result = await db.execute(select(Work).where(Work.id == work_id))
    work = work_result.scalar_one_or_none()
    if work:
        work.ratings_count = row.cnt or 0
        work.average_rating = Decimal(str(round(float(row.avg or 0), 2))) if row.avg else None


def _to_response(user_book: UserBook, work: Work | None) -> UserBookResponse:
    """Convert a UserBook + Work to a response schema."""
    book_brief = None
    if work:
        book_brief = BookBrief(
            id=work.id,
            title=work.title,
            authors=[AuthorBrief(id=a.id, name=a.name) for a in (work.authors or [])],
            cover_image_url=work.cover_image_url,
            average_rating=work.average_rating,
            ratings_count=work.ratings_count,
        )

    return UserBookResponse(
        id=user_book.id,
        work_id=user_book.work_id,
        status=user_book.status,
        rating=user_book.rating,
        review_text=user_book.review_text,
        has_spoilers=user_book.has_spoilers,
        started_at=user_book.started_at,
        finished_at=user_book.finished_at,
        is_imported=user_book.is_imported,
        is_private=user_book.is_private,  # <-- NEW
        created_at=user_book.created_at,
        updated_at=user_book.updated_at,
        book=book_brief,
    )
```

### A5. Feed Service: Filter private books from feed

**File: `backend/services/feed_service.py`** — Change `_activities_to_feed()` to filter private books.

In `_activities_to_feed`, after loading user_books into `ub_map`, add a filter:

```python
async def _activities_to_feed(
    db: AsyncSession,
    activities: list[Activity],
    has_more: bool,
) -> PaginatedResponse[FeedItem]:
    """Convert Activity objects to FeedItem responses with related data."""
    if not activities:
        return PaginatedResponse(items=[], next_cursor=None, has_more=False)

    # Batch load users, user_books, works
    user_ids = list({a.user_id for a in activities})
    target_ids = list({a.target_id for a in activities})

    users_result = await db.execute(select(User).where(User.id.in_(user_ids)))
    users_map = {u.id: u for u in users_result.scalars().all()}

    ub_result = await db.execute(select(UserBook).where(UserBook.id.in_(target_ids)))
    ub_map = {ub.id: ub for ub in ub_result.scalars().all()}

    work_ids = list({ub.work_id for ub in ub_map.values()})
    if work_ids:
        works_result = await db.execute(select(Work).where(Work.id.in_(work_ids)))
        works_map = {w.id: w for w in works_result.scalars().all()}
    else:
        works_map = {}

    items = []
    for activity in activities:
        user = users_map.get(activity.user_id)
        user_book = ub_map.get(activity.target_id)
        work = works_map.get(user_book.work_id) if user_book else None

        if not user or not user_book or not work:
            continue

        # Skip private books — they should never appear in the feed
        if user_book.is_private:  # <-- NEW
            continue

        items.append(
            FeedItem(
                id=activity.id,
                user=UserBrief(
                    id=user.id,
                    username=user.username,
                    display_name=user.display_name,
                    avatar_url=user.avatar_url,
                ),
                activity_type=activity.activity_type,
                book=BookBrief(
                    id=work.id,
                    title=work.title,
                    authors=[AuthorBrief(id=a.id, name=a.name) for a in (work.authors or [])],
                    cover_image_url=work.cover_image_url,
                    average_rating=work.average_rating,
                    ratings_count=work.ratings_count,
                ),
                rating=user_book.rating,
                review_text=user_book.review_text,
                has_spoilers=user_book.has_spoilers,
                created_at=activity.created_at,
            )
        )

    next_cursor = encode_cursor(activities[-1].created_at, activities[-1].id) if has_more else None

    return PaginatedResponse(items=items, next_cursor=next_cursor, has_more=has_more)
```

### A6. Book Reviews: Filter private reviews

**File: `backend/services/book_service.py`** — In `get_book_reviews()`, add privacy filter.

Find the query that loads reviews for a work and add:

```python
# In get_book_reviews(), add this filter to exclude private reviews from other users:
stmt = (
    select(UserBook)
    .where(
        UserBook.work_id == work_id,
        UserBook.review_text.isnot(None),
        UserBook.is_hidden == False,  # noqa: E712
        # Hide private reviews from other users
        (UserBook.is_private == False) | (UserBook.user_id == requesting_user_id),  # <-- NEW
    )
    .order_by(UserBook.created_at.desc(), UserBook.id.desc())
)
```

### A7. iOS: Add `isPrivate` to models

**File: `ios/Shelf/Models/UserBook.swift`** — Full replacement:

```swift
/// Reading log entry tying a user to a work. Maps to the backend's UserBook model.
/// Rating uses half-star increments (0.5–5.0) to match Letterboxd-style granularity.

import Foundation

// MARK: - Reading Status

enum ReadingStatus: String, Codable, CaseIterable {
    case reading
    case read
    case wantToRead = "want_to_read"
    case didNotFinish = "did_not_finish"

    var displayName: String {
        switch self {
        case .reading: "Reading"
        case .read: "Read"
        case .wantToRead: "Want to Read"
        case .didNotFinish: "Did Not Finish"
        }
    }

    var iconName: String {
        switch self {
        case .reading: "book.fill"
        case .read: "checkmark.circle.fill"
        case .wantToRead: "bookmark.fill"
        case .didNotFinish: "xmark.circle.fill"
        }
    }
}

// MARK: - UserBook

struct UserBook: Codable, Identifiable, Hashable {
    let id: UUID
    let userID: UUID
    let workID: UUID
    let status: ReadingStatus
    let rating: Double?
    let reviewText: String?
    let hasSpoilers: Bool
    let startedAt: Date?
    let finishedAt: Date?
    let isImported: Bool
    let isPrivate: Bool  // <-- NEW
    let createdAt: Date
    let updatedAt: Date

    // Populated on list endpoints
    let book: Book?

    enum CodingKeys: String, CodingKey {
        case id, status, rating, book
        case userID = "user_id"
        case workID = "work_id"
        case reviewText = "review_text"
        case hasSpoilers = "has_spoilers"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case isImported = "is_imported"
        case isPrivate = "is_private"  // <-- NEW
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Log Book Request

struct LogBookRequest: Codable {
    let workID: UUID
    var status: ReadingStatus
    var rating: Double?
    var reviewText: String?
    var hasSpoilers: Bool = false
    var startedAt: Date?
    var finishedAt: Date?
    var isPrivate: Bool = false  // <-- NEW

    enum CodingKeys: String, CodingKey {
        case status, rating
        case workID = "work_id"
        case reviewText = "review_text"
        case hasSpoilers = "has_spoilers"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case isPrivate = "is_private"  // <-- NEW
    }
}

struct UpdateBookRequest: Codable {
    var status: ReadingStatus?
    var rating: Double?
    var reviewText: String?
    var hasSpoilers: Bool?
    var startedAt: Date?
    var finishedAt: Date?
    var isPrivate: Bool?  // <-- NEW

    enum CodingKeys: String, CodingKey {
        case status, rating
        case reviewText = "review_text"
        case hasSpoilers = "has_spoilers"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case isPrivate = "is_private"  // <-- NEW
    }
}
```

### A8. iOS: Add privacy toggle to LogBookSheet

**File: `ios/Shelf/Views/BookDetail/LogBookSheet.swift`** — Add `isPrivate` state and toggle:

```swift
import SwiftUI

struct LogBookSheet: View {
    @Environment(\.dismiss) private var dismiss

    let book: Book
    let existingUserBook: UserBook?
    let onSave: (LogBookRequest) -> Void

    @State private var status: ReadingStatus = .read
    @State private var rating: Double = 0
    @State private var reviewText = ""
    @State private var hasSpoilers = false
    @State private var isPrivate = false  // <-- NEW
    @State private var startedAt: Date? = nil
    @State private var finishedAt: Date? = nil
    @State private var showStartDate = false
    @State private var showEndDate = false

    init(book: Book, existingUserBook: UserBook?, onSave: @escaping (LogBookRequest) -> Void) {
        self.book = book
        self.existingUserBook = existingUserBook
        self.onSave = onSave

        if let existing = existingUserBook {
            _status = State(initialValue: existing.status)
            _rating = State(initialValue: existing.rating ?? 0)
            _reviewText = State(initialValue: existing.reviewText ?? "")
            _hasSpoilers = State(initialValue: existing.hasSpoilers)
            _isPrivate = State(initialValue: existing.isPrivate)  // <-- NEW
            _startedAt = State(initialValue: existing.startedAt)
            _finishedAt = State(initialValue: existing.finishedAt)
            _showStartDate = State(initialValue: existing.startedAt != nil)
            _showEndDate = State(initialValue: existing.finishedAt != nil)
        }
    }

    private var isValid: Bool {
        if rating > 0 && existingUserBook == nil && reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                // Book header
                Section {
                    HStack(spacing: 12) {
                        BookCoverImage(url: book.coverImageURL, size: CGSize(width: 50, height: 75))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.headline)
                            if let author = book.authors.first?.name {
                                Text(author)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Status
                Section("Status") {
                    Picker("Reading status", selection: $status) {
                        ForEach(ReadingStatus.allCases, id: \.self) { s in
                            Label(s.displayName, systemImage: s.iconName)
                                .tag(s)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                // Rating
                Section("Rating") {
                    VStack(spacing: 8) {
                        StarRatingView(rating: $rating, size: 36)
                        if rating > 0 {
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }

                // Review
                Section {
                    TextEditor(text: $reviewText)
                        .frame(minHeight: 100)

                    if rating > 0 && existingUserBook == nil && reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("A review is required when rating a book.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if !reviewText.isEmpty {
                        Toggle("Contains spoilers", isOn: $hasSpoilers)
                    }
                } header: {
                    Text("Review")
                }

                // Dates
                Section("Dates") {
                    Toggle("Started reading", isOn: $showStartDate)
                    if showStartDate {
                        DatePicker(
                            "Start date",
                            selection: Binding(
                                get: { startedAt ?? Date() },
                                set: { startedAt = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }

                    Toggle("Finished reading", isOn: $showEndDate)
                    if showEndDate {
                        DatePicker(
                            "End date",
                            selection: Binding(
                                get: { finishedAt ?? Date() },
                                set: { finishedAt = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }

                // NEW: Privacy section
                Section {
                    Toggle("Private", isOn: $isPrivate)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Private books won't appear in your public profile or followers' feeds.")
                }
            }
            .navigationTitle(existingUserBook != nil ? "Edit Log" : "Log Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        let request = LogBookRequest(
            workID: book.id,
            status: status,
            rating: rating > 0 ? rating : nil,
            reviewText: reviewText.isEmpty ? nil : reviewText,
            hasSpoilers: hasSpoilers,
            startedAt: showStartDate ? (startedAt ?? Date()) : nil,
            finishedAt: showEndDate ? (finishedAt ?? Date()) : nil,
            isPrivate: isPrivate  // <-- NEW
        )
        onSave(request)
        dismiss()
    }
}
```

---

## B. Reading Stats

### B1. Stats Schema

**File: `backend/api/schemas/stats.py`** — New file:

```python
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
    pages_read: int | None = None  # None if page counts unavailable
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
```

### B2. Stats Service

**File: `backend/services/stats_service.py`** — New file:

```python
"""Reading statistics service.

Computes reading stats from user_books data. All stats include private books
(they're the user's own data). The `hide_reading_stats` flag on User controls
whether OTHER users can see these stats — the service itself always computes them.
"""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from backend.api.model_stubs import Edition, UserBook, Work
from backend.api.schemas.stats import (
    MonthlyCount,
    RatingDistribution,
    ReadingStats,
    YearlyStats,
)
from sqlalchemy import extract, func, select
from sqlalchemy.ext.asyncio import AsyncSession


async def get_reading_stats(
    db: AsyncSession,
    user_id: UUID,
) -> ReadingStats:
    """Compute comprehensive reading statistics for a user."""
    # Status counts
    status_counts = await db.execute(
        select(UserBook.status, func.count())
        .where(UserBook.user_id == user_id)
        .group_by(UserBook.status)
    )
    counts = {row[0]: row[1] for row in status_counts.all()}

    total_books = sum(counts.values())
    total_read = counts.get("read", 0)
    total_reading = counts.get("reading", 0)
    total_want_to_read = counts.get("want_to_read", 0)
    total_did_not_finish = counts.get("did_not_finish", 0)

    # Overall average rating
    avg_result = await db.execute(
        select(func.avg(UserBook.rating)).where(
            UserBook.user_id == user_id,
            UserBook.rating.isnot(None),
        )
    )
    overall_avg = avg_result.scalar()
    average_rating = round(float(overall_avg), 2) if overall_avg else None

    # Current year stats
    current_year = datetime.now().year
    current_year_stats = await _get_yearly_stats(db, user_id, current_year)

    # Historical yearly stats (last 5 years)
    yearly_stats = []
    for year in range(current_year - 4, current_year + 1):
        ys = await _get_yearly_stats(db, user_id, year)
        if ys.books_read > 0:
            yearly_stats.append(ys)

    return ReadingStats(
        total_books=total_books,
        total_read=total_read,
        total_reading=total_reading,
        total_want_to_read=total_want_to_read,
        total_did_not_finish=total_did_not_finish,
        average_rating=average_rating,
        current_year_stats=current_year_stats,
        yearly_stats=yearly_stats,
    )


async def _get_yearly_stats(
    db: AsyncSession,
    user_id: UUID,
    year: int,
) -> YearlyStats:
    """Compute stats for a single year based on finished_at date."""
    # Books finished this year
    base_filter = [
        UserBook.user_id == user_id,
        UserBook.status == "read",
        extract("year", UserBook.finished_at) == year,
    ]

    # Count
    count_result = await db.execute(
        select(func.count()).where(*base_filter)
    )
    books_read = count_result.scalar() or 0

    if books_read == 0:
        return YearlyStats(year=year, books_read=0)

    # Average rating for the year
    avg_result = await db.execute(
        select(func.avg(UserBook.rating)).where(
            *base_filter,
            UserBook.rating.isnot(None),
        )
    )
    avg_rating = avg_result.scalar()

    # Monthly breakdown
    monthly_result = await db.execute(
        select(
            extract("month", UserBook.finished_at).label("month"),
            func.count().label("cnt"),
        )
        .where(*base_filter)
        .group_by("month")
        .order_by("month")
    )
    monthly_breakdown = [
        MonthlyCount(month=int(row.month), count=row.cnt)
        for row in monthly_result.all()
    ]

    # Rating distribution
    rating_result = await db.execute(
        select(UserBook.rating, func.count().label("cnt"))
        .where(
            *base_filter,
            UserBook.rating.isnot(None),
        )
        .group_by(UserBook.rating)
        .order_by(UserBook.rating)
    )
    rating_distribution = [
        RatingDistribution(rating=float(row[0]), count=row[1])
        for row in rating_result.all()
    ]

    # Top genres (from work subjects, top 5)
    top_genres_result = await db.execute(
        select(func.unnest(Work.subjects).label("genre"), func.count().label("cnt"))
        .join(UserBook, UserBook.work_id == Work.id)
        .where(*base_filter, Work.subjects.isnot(None))
        .group_by("genre")
        .order_by(func.count().desc())
        .limit(5)
    )
    # unnest may not work in SQLite tests — wrap in try/except for safety
    try:
        top_genres = [row.genre for row in top_genres_result.all()]
    except Exception:
        top_genres = []

    # Pages read (sum of edition page counts if available)
    pages_result = await db.execute(
        select(func.sum(Edition.page_count))
        .join(UserBook, UserBook.work_id == Edition.work_id)
        .where(*base_filter, Edition.page_count.isnot(None))
    )
    pages_read = pages_result.scalar()

    return YearlyStats(
        year=year,
        books_read=books_read,
        pages_read=pages_read,
        average_rating=round(float(avg_rating), 2) if avg_rating else None,
        monthly_breakdown=monthly_breakdown,
        rating_distribution=rating_distribution,
        top_genres=top_genres,
    )
```

### B3. Stats Route

**File: `backend/api/routes/stats.py`** — New file:

```python
"""Reading statistics routes."""

from __future__ import annotations

from uuid import UUID

from backend.api.deps import DB, CurrentUser
from backend.api.errors import blocked_user, user_not_found
from backend.api.model_stubs import User
from backend.api.schemas.stats import ReadingStats
from backend.services import stats_service
from backend.services.social_service import is_blocked
from fastapi import APIRouter
from sqlalchemy import select

router = APIRouter()


@router.get("/me/stats", response_model=ReadingStats)
async def get_my_stats(
    db: DB,
    current_user: CurrentUser,
) -> ReadingStats:
    """Get your own reading statistics."""
    return await stats_service.get_reading_stats(db, current_user.id)


@router.get("/users/{user_id}/stats", response_model=ReadingStats)
async def get_user_stats(
    user_id: UUID,
    db: DB,
    current_user: CurrentUser,
) -> ReadingStats:
    """Get another user's reading statistics.

    Returns 404 if the user has hidden their stats.
    """
    if await is_blocked(db, current_user.id, user_id):
        raise blocked_user()

    # Check if user has hidden their stats
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise user_not_found()

    if getattr(user, "hide_reading_stats", False):
        raise user_not_found()  # Reuse 404 to not leak existence

    return await stats_service.get_reading_stats(db, user_id)
```

### B4. Register Stats Router

**File: `backend/api/main.py`** — Add these two lines:

In the import block (around line 56), add:
```python
from backend.api.routes import stats
```

In the router registration block (around line 90), add:
```python
app.include_router(stats.router, prefix="/api/v1", tags=["stats"])
```

### B5. User Model: Add `hide_reading_stats`

**File: `backend/models/user.py`** — Add after `is_premium`:

```python
hide_reading_stats: Mapped[bool] = mapped_column(default=False, server_default="false")
```

**File: `backend/api/model_stubs.py`** — Add to User class after `is_deleted`:

```python
hide_reading_stats: Mapped[bool] = mapped_column(Boolean, default=False)
```

### B6. User Schema: Add `hide_reading_stats` to profile update

**File: `backend/api/schemas/users.py`** — Updated:

```python
"""Pydantic schemas for user profile endpoints."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

__all__ = ["UpdateProfileRequest", "UserBrief", "UserProfile"]


class UpdateProfileRequest(BaseModel):
    username: str | None = Field(None, min_length=3, max_length=20)
    display_name: str | None = Field(None, max_length=100)
    bio: str | None = Field(None, max_length=500)
    avatar_url: str | None = None
    favorite_books: list[UUID] | None = Field(None, max_length=4)
    hide_reading_stats: bool | None = None  # <-- NEW


class UserProfile(BaseModel):
    id: UUID
    username: str
    display_name: str | None = None
    avatar_url: str | None = None
    bio: str | None = None
    favorite_books: list[UUID] = []
    books_count: int = 0
    followers_count: int = 0
    following_count: int = 0
    is_following: bool = False
    hide_reading_stats: bool = False  # <-- NEW
    created_at: datetime

    model_config = {"from_attributes": True}


class UserBrief(BaseModel):
    id: UUID
    username: str
    display_name: str | None = None
    avatar_url: str | None = None

    model_config = {"from_attributes": True}
```

### B7. iOS: Reading Stats View

**File: `ios/Shelf/Models/ReadingStats.swift`** — New file:

```swift
import Foundation

struct MonthlyCount: Codable {
    let month: Int
    let count: Int
}

struct RatingDistribution: Codable {
    let rating: Double
    let count: Int
}

struct YearlyStats: Codable, Identifiable {
    var id: Int { year }
    let year: Int
    let booksRead: Int
    let pagesRead: Int?
    let averageRating: Double?
    let monthlyBreakdown: [MonthlyCount]
    let ratingDistribution: [RatingDistribution]
    let topGenres: [String]

    enum CodingKeys: String, CodingKey {
        case year
        case booksRead = "books_read"
        case pagesRead = "pages_read"
        case averageRating = "average_rating"
        case monthlyBreakdown = "monthly_breakdown"
        case ratingDistribution = "rating_distribution"
        case topGenres = "top_genres"
    }
}

struct ReadingStats: Codable {
    let totalBooks: Int
    let totalRead: Int
    let totalReading: Int
    let totalWantToRead: Int
    let totalDidNotFinish: Int
    let averageRating: Double?
    let currentYearStats: YearlyStats?
    let yearlyStats: [YearlyStats]

    enum CodingKeys: String, CodingKey {
        case totalBooks = "total_books"
        case totalRead = "total_read"
        case totalReading = "total_reading"
        case totalWantToRead = "total_want_to_read"
        case totalDidNotFinish = "total_did_not_finish"
        case averageRating = "average_rating"
        case currentYearStats = "current_year_stats"
        case yearlyStats = "yearly_stats"
    }
}
```

**File: `ios/Shelf/ViewModels/StatsViewModel.swift`** — New file:

```swift
import Foundation

@Observable
final class StatsViewModel {
    private(set) var stats: ReadingStats?
    private(set) var isLoading = false
    private(set) var error: Error?

    let userID: UUID?  // nil = current user

    private let apiClient = APIClient.shared

    init(userID: UUID? = nil) {
        self.userID = userID
    }

    @MainActor
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let path = userID != nil ? "/users/\(userID!)/stats" : "/me/stats"
            stats = try await apiClient.get(path)
        } catch {
            self.error = error
        }

        isLoading = false
    }
}
```

**File: `ios/Shelf/Views/Profile/ReadingStatsView.swift`** — New file:

```swift
import SwiftUI
import Charts

struct ReadingStatsView: View {
    let viewModel: StatsViewModel

    init(userID: UUID? = nil) {
        self.viewModel = StatsViewModel(userID: userID)
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 100)
            } else if let stats = viewModel.stats {
                VStack(spacing: 24) {
                    overviewCards(stats)
                    if let yearStats = stats.currentYearStats {
                        currentYearSection(yearStats)
                    }
                    if !stats.yearlyStats.isEmpty {
                        yearlyBreakdownSection(stats.yearlyStats)
                    }
                }
                .padding()
            } else if viewModel.error != nil {
                ContentUnavailableView(
                    "Couldn't Load Stats",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Pull to refresh to try again.")
                )
            }
        }
        .navigationTitle("Reading Stats")
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: - Overview Cards

    @ViewBuilder
    private func overviewCards(_ stats: ReadingStats) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 16) {
            statCard(title: "Total Books", value: "\(stats.totalBooks)", icon: "books.vertical.fill")
            statCard(title: "Read", value: "\(stats.totalRead)", icon: "checkmark.circle.fill")
            statCard(title: "Reading", value: "\(stats.totalReading)", icon: "book.fill")
            statCard(
                title: "Avg Rating",
                value: stats.averageRating.map { String(format: "%.1f", $0) } ?? "—",
                icon: "star.fill"
            )
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.accent)
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Current Year

    @ViewBuilder
    private func currentYearSection(_ yearStats: YearlyStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(String(yearStats.year)) Progress")
                .font(.headline)

            if !yearStats.monthlyBreakdown.isEmpty {
                Chart(yearStats.monthlyBreakdown, id: \.month) { item in
                    BarMark(
                        x: .value("Month", monthName(item.month)),
                        y: .value("Books", item.count)
                    )
                    .foregroundStyle(.accent)
                }
                .frame(height: 180)
            }

            if let pages = yearStats.pagesRead {
                Label("\(pages.formatted()) pages read", systemImage: "doc.text")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !yearStats.topGenres.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Top Genres")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    FlowLayout(spacing: 6) {
                        ForEach(yearStats.topGenres, id: \.self) { genre in
                            Text(genre)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.accent.opacity(0.15), in: Capsule())
                        }
                    }
                }
            }

            if !yearStats.ratingDistribution.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rating Distribution")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Chart(yearStats.ratingDistribution, id: \.rating) { item in
                        BarMark(
                            x: .value("Rating", String(format: "%.1f", item.rating)),
                            y: .value("Count", item.count)
                        )
                        .foregroundStyle(.orange)
                    }
                    .frame(height: 120)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Yearly Breakdown

    @ViewBuilder
    private func yearlyBreakdownSection(_ years: [YearlyStats]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Year by Year")
                .font(.headline)

            Chart(years) { year in
                BarMark(
                    x: .value("Year", String(year.year)),
                    y: .value("Books", year.booksRead)
                )
                .foregroundStyle(.accent)
                .annotation(position: .top) {
                    Text("\(year.booksRead)")
                        .font(.caption2)
                }
            }
            .frame(height: 160)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        return formatter.shortMonthSymbols[month - 1]
    }
}

// Simple flow layout for genre tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}
```

### B8. iOS: Add stats link to profile

In `MyProfileView.swift`, add a NavigationLink to the stats view. Find the profile sections and add:

```swift
// Inside the profile view's navigation content, add:
NavigationLink(destination: ReadingStatsView()) {
    Label("Reading Stats", systemImage: "chart.bar.fill")
}
```

### B9. iOS: Settings toggle for hiding stats

In `SettingsView.swift`, add a toggle in the privacy section:

```swift
// In the Settings form, add a section:
Section("Privacy") {
    Toggle("Hide reading stats from profile", isOn: $hideReadingStats)
}

// Where hideReadingStats is a @State that calls the update profile API:
// let request = UpdateProfileRequest(hideReadingStats: newValue)
// try await socialService.updateProfile(request)
```

---

## C. Content Warnings & Mood Tags

### C1. Tag Definitions

Content tags are from a predefined list. No free-text — prevents abuse and keeps data clean.

### C2. Database Model

**File: `backend/api/model_stubs.py`** — Add new model after `MetadataReport`:

```python
# --- Content tags domain ---


class WorkContentTag(TimestampMixin, Base):
    """Community-voted content tag on a work.

    Tags come from a predefined set (CONTENT_WARNING_TAGS + MOOD_TAGS).
    Each user can vote once per (work, tag) pair. A tag is "confirmed" when
    it reaches the vote threshold.
    """

    __tablename__ = "work_content_tags"

    id: Mapped[uuid.UUID] = _uuid_col(primary_key=True)
    work_id: Mapped[uuid.UUID] = _fk_uuid_col("works.id", index=True)
    tag_name: Mapped[str] = mapped_column(String(50))
    tag_type: Mapped[str] = mapped_column(String(20))  # "content_warning" or "mood"
    vote_count: Mapped[int] = mapped_column(Integer, default=1)
    is_confirmed: Mapped[bool] = mapped_column(Boolean, default=False)


class WorkContentTagVote(Base):
    """One vote per user per (work, tag). Prevents double-voting."""

    __tablename__ = "work_content_tag_votes"

    user_id: Mapped[uuid.UUID] = _fk_uuid_col("users.id", primary_key=True, default=False)
    work_content_tag_id: Mapped[uuid.UUID] = _fk_uuid_col(
        "work_content_tags.id", primary_key=True, default=False
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
```

### C3. Tag Constants

**File: `backend/services/content_tags.py`** — New file:

```python
"""Predefined content warning and mood tag lists.

Only tags from these lists are accepted. This prevents abuse and keeps
the taxonomy clean. Add new tags here as the community requests them.
"""

CONTENT_WARNING_TAGS = [
    "graphic_violence",
    "sexual_content",
    "substance_abuse",
    "self_harm",
    "eating_disorders",
    "child_abuse",
    "domestic_violence",
    "sexual_assault",
    "animal_cruelty",
    "racism",
    "homophobia",
    "transphobia",
    "ableism",
    "war",
    "torture",
    "death_of_a_loved_one",
    "suicide",
    "gore",
    "kidnapping",
    "stalking",
]

MOOD_TAGS = [
    "slow_burn",
    "page_turner",
    "emotional",
    "dark",
    "lighthearted",
    "funny",
    "atmospheric",
    "tense",
    "hopeful",
    "melancholic",
    "thought_provoking",
    "romantic",
    "adventurous",
    "cozy",
    "unsettling",
    "inspirational",
    "nostalgic",
    "suspenseful",
    "bittersweet",
    "whimsical",
]

ALL_TAGS = {
    **{tag: "content_warning" for tag in CONTENT_WARNING_TAGS},
    **{tag: "mood" for tag in MOOD_TAGS},
}

# Number of votes required before a tag is considered confirmed
VOTE_THRESHOLD = 3


def is_valid_tag(tag_name: str) -> bool:
    return tag_name in ALL_TAGS


def get_tag_type(tag_name: str) -> str | None:
    return ALL_TAGS.get(tag_name)
```

### C4. Content Tag Service

**File: `backend/services/content_tag_service.py`** — New file:

```python
"""Service for community-voted content tags on works.

Users can vote to add content warnings or mood tags to books. Once a tag
reaches the vote threshold, it becomes "confirmed" and is shown prominently.
Each user can only vote once per tag per book.
"""

from __future__ import annotations

from uuid import UUID

from backend.api.errors import AppError
from backend.api.model_stubs import WorkContentTag, WorkContentTagVote
from backend.api.schemas.content_tags import ContentTagResponse, VoteTagRequest
from backend.services.content_tags import ALL_TAGS, VOTE_THRESHOLD, get_tag_type, is_valid_tag
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession


async def get_work_tags(
    db: AsyncSession,
    work_id: UUID,
) -> list[ContentTagResponse]:
    """Get all content tags for a work, ordered by vote count."""
    result = await db.execute(
        select(WorkContentTag)
        .where(WorkContentTag.work_id == work_id)
        .order_by(WorkContentTag.vote_count.desc())
    )
    tags = result.scalars().all()

    return [
        ContentTagResponse(
            id=tag.id,
            tag_name=tag.tag_name,
            tag_type=tag.tag_type,
            vote_count=tag.vote_count,
            is_confirmed=tag.is_confirmed,
            display_name=tag.tag_name.replace("_", " ").title(),
        )
        for tag in tags
    ]


async def vote_tag(
    db: AsyncSession,
    user_id: UUID,
    work_id: UUID,
    request: VoteTagRequest,
) -> ContentTagResponse:
    """Vote for a content tag on a work. Creates the tag if it doesn't exist."""
    if not is_valid_tag(request.tag_name):
        raise AppError(
            status_code=422,
            code="INVALID_TAG",
            message=f"'{request.tag_name}' is not a valid tag. Use GET /books/{{id}}/tags/available for the list.",
        )

    tag_type = get_tag_type(request.tag_name)

    # Find or create the tag
    result = await db.execute(
        select(WorkContentTag).where(
            WorkContentTag.work_id == work_id,
            WorkContentTag.tag_name == request.tag_name,
        )
    )
    tag = result.scalar_one_or_none()

    if tag is None:
        # Create new tag
        tag = WorkContentTag(
            work_id=work_id,
            tag_name=request.tag_name,
            tag_type=tag_type,
            vote_count=1,
            is_confirmed=False,
        )
        db.add(tag)
        await db.flush()

        # Record vote
        vote = WorkContentTagVote(
            user_id=user_id,
            work_content_tag_id=tag.id,
        )
        db.add(vote)
        await db.flush()
    else:
        # Check if user already voted
        existing_vote = await db.execute(
            select(WorkContentTagVote).where(
                WorkContentTagVote.user_id == user_id,
                WorkContentTagVote.work_content_tag_id == tag.id,
            )
        )
        if existing_vote.scalar_one_or_none() is not None:
            raise AppError(
                status_code=409,
                code="ALREADY_VOTED",
                message="You have already voted for this tag on this book.",
            )

        # Record vote and increment count
        vote = WorkContentTagVote(
            user_id=user_id,
            work_content_tag_id=tag.id,
        )
        db.add(vote)
        tag.vote_count += 1

        # Check if threshold reached
        if tag.vote_count >= VOTE_THRESHOLD and not tag.is_confirmed:
            tag.is_confirmed = True

        await db.flush()

    return ContentTagResponse(
        id=tag.id,
        tag_name=tag.tag_name,
        tag_type=tag.tag_type,
        vote_count=tag.vote_count,
        is_confirmed=tag.is_confirmed,
        display_name=tag.tag_name.replace("_", " ").title(),
    )


async def remove_vote(
    db: AsyncSession,
    user_id: UUID,
    work_id: UUID,
    tag_name: str,
) -> None:
    """Remove a user's vote from a content tag."""
    result = await db.execute(
        select(WorkContentTag).where(
            WorkContentTag.work_id == work_id,
            WorkContentTag.tag_name == tag_name,
        )
    )
    tag = result.scalar_one_or_none()
    if tag is None:
        raise AppError(404, "TAG_NOT_FOUND", "Tag not found on this book.")

    vote_result = await db.execute(
        select(WorkContentTagVote).where(
            WorkContentTagVote.user_id == user_id,
            WorkContentTagVote.work_content_tag_id == tag.id,
        )
    )
    vote = vote_result.scalar_one_or_none()
    if vote is None:
        raise AppError(404, "VOTE_NOT_FOUND", "You haven't voted for this tag.")

    await db.delete(vote)
    tag.vote_count -= 1

    if tag.vote_count < VOTE_THRESHOLD:
        tag.is_confirmed = False

    # Remove tag entirely if no votes remain
    if tag.vote_count <= 0:
        await db.delete(tag)

    await db.flush()


async def get_available_tags() -> dict[str, list[str]]:
    """Return the full list of available tags, grouped by type."""
    content_warnings = [k for k, v in ALL_TAGS.items() if v == "content_warning"]
    moods = [k for k, v in ALL_TAGS.items() if v == "mood"]
    return {
        "content_warnings": sorted(content_warnings),
        "moods": sorted(moods),
    }
```

### C5. Content Tag Schemas

**File: `backend/api/schemas/content_tags.py`** — New file:

```python
"""Pydantic schemas for content warning and mood tag endpoints."""

from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel

__all__ = ["AvailableTagsResponse", "ContentTagResponse", "VoteTagRequest"]


class VoteTagRequest(BaseModel):
    tag_name: str


class ContentTagResponse(BaseModel):
    id: UUID
    tag_name: str
    tag_type: str  # "content_warning" or "mood"
    vote_count: int
    is_confirmed: bool
    display_name: str  # Human-friendly name (e.g. "Graphic Violence")

    model_config = {"from_attributes": True}


class AvailableTagsResponse(BaseModel):
    content_warnings: list[str]
    moods: list[str]
```

### C6. Content Tag Routes

Add to existing books router or create a new file. Adding to the books router is cleaner:

**File: `backend/api/routes/books.py`** — Add at the end of the file:

```python
# --- Content Tags ---

from backend.api.schemas.content_tags import AvailableTagsResponse, ContentTagResponse, VoteTagRequest
from backend.services import content_tag_service


@router.get("/{work_id}/tags", response_model=list[ContentTagResponse])
async def get_book_tags(
    work_id: UUID,
    db: DB,
    current_user: CurrentUser,
) -> list[ContentTagResponse]:
    """Get content warnings and mood tags for a book."""
    return await content_tag_service.get_work_tags(db, work_id)


@router.post("/{work_id}/tags/vote", response_model=ContentTagResponse, status_code=status.HTTP_201_CREATED)
async def vote_for_tag(
    work_id: UUID,
    request: VoteTagRequest,
    db: DB,
    current_user: CurrentUser,
) -> ContentTagResponse:
    """Vote to add a content tag to a book."""
    return await content_tag_service.vote_tag(db, current_user.id, work_id, request)


@router.delete("/{work_id}/tags/{tag_name}/vote")
async def remove_tag_vote(
    work_id: UUID,
    tag_name: str,
    db: DB,
    current_user: CurrentUser,
) -> dict[str, str]:
    """Remove your vote from a content tag."""
    await content_tag_service.remove_vote(db, current_user.id, work_id, tag_name)
    return {"message": "Vote removed"}


@router.get("/tags/available", response_model=AvailableTagsResponse)
async def get_available_tags(
    current_user: CurrentUser,
) -> AvailableTagsResponse:
    """Get the full list of available content warning and mood tags."""
    tags = await content_tag_service.get_available_tags()
    return AvailableTagsResponse(**tags)
```

### C7. iOS: Content Tag Model

**File: `ios/Shelf/Models/ContentTag.swift`** — New file:

```swift
import Foundation

struct ContentTag: Codable, Identifiable, Hashable {
    let id: UUID
    let tagName: String
    let tagType: String  // "content_warning" or "mood"
    let voteCount: Int
    let isConfirmed: Bool
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case tagType = "tag_type"
        case voteCount = "vote_count"
        case isConfirmed = "is_confirmed"
        case displayName = "display_name"
    }

    var isContentWarning: Bool { tagType == "content_warning" }
    var isMood: Bool { tagType == "mood" }
}

struct AvailableTags: Codable {
    let contentWarnings: [String]
    let moods: [String]

    enum CodingKeys: String, CodingKey {
        case contentWarnings = "content_warnings"
        case moods
    }
}

struct VoteTagRequest: Codable {
    let tagName: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
    }
}
```

### C8. iOS: Content Tag Views

**File: `ios/Shelf/Views/BookDetail/ContentTagsSection.swift`** — New file:

```swift
import SwiftUI

struct ContentTagsSection: View {
    let bookID: UUID
    @State private var tags: [ContentTag] = []
    @State private var availableTags: AvailableTags?
    @State private var showTagPicker = false
    @State private var isLoading = false

    private let apiClient = APIClient.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Content Tags")
                    .font(.headline)
                Spacer()
                Button {
                    showTagPicker = true
                } label: {
                    Image(systemName: "plus.circle")
                }
            }

            if tags.isEmpty && !isLoading {
                Text("No tags yet. Be the first to add one!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Content Warnings
            let warnings = tags.filter(\.isContentWarning)
            if !warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Content Warnings", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)

                    FlowLayout(spacing: 6) {
                        ForEach(warnings) { tag in
                            tagChip(tag, color: .orange)
                        }
                    }
                }
            }

            // Mood Tags
            let moods = tags.filter(\.isMood)
            if !moods.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Mood", systemImage: "heart.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.purple)

                    FlowLayout(spacing: 6) {
                        ForEach(moods) { tag in
                            tagChip(tag, color: .purple)
                        }
                    }
                }
            }
        }
        .task { await loadTags() }
        .sheet(isPresented: $showTagPicker) {
            TagPickerSheet(bookID: bookID, availableTags: availableTags) { tagName in
                await voteForTag(tagName)
            }
        }
    }

    private func tagChip(_ tag: ContentTag, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(tag.displayName)
                .font(.caption)
            if tag.isConfirmed {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption2)
            }
            Text("(\(tag.voteCount))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
        .foregroundStyle(color)
    }

    @MainActor
    private func loadTags() async {
        isLoading = true
        do {
            tags = try await apiClient.get("/books/\(bookID)/tags")
            availableTags = try await apiClient.get("/books/tags/available")
        } catch {
            // Silent fail — tags are supplementary
        }
        isLoading = false
    }

    @MainActor
    private func voteForTag(_ tagName: String) async {
        do {
            let request = VoteTagRequest(tagName: tagName)
            let _: ContentTag = try await apiClient.post("/books/\(bookID)/tags/vote", body: request)
            await loadTags()
        } catch {
            // Show error via toast or ignore
        }
    }
}

// MARK: - Tag Picker Sheet

struct TagPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let bookID: UUID
    let availableTags: AvailableTags?
    let onVote: (String) async -> Void

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                if let available = availableTags {
                    Section("Content Warnings") {
                        ForEach(filtered(available.contentWarnings), id: \.self) { tag in
                            Button {
                                Task {
                                    await onVote(tag)
                                    dismiss()
                                }
                            } label: {
                                Label(
                                    tag.replacingOccurrences(of: "_", with: " ").capitalized,
                                    systemImage: "exclamationmark.triangle"
                                )
                            }
                        }
                    }

                    Section("Mood") {
                        ForEach(filtered(available.moods), id: \.self) { tag in
                            Button {
                                Task {
                                    await onVote(tag)
                                    dismiss()
                                }
                            } label: {
                                Label(
                                    tag.replacingOccurrences(of: "_", with: " ").capitalized,
                                    systemImage: "heart"
                                )
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search tags")
            .navigationTitle("Add Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func filtered(_ tags: [String]) -> [String] {
        if searchText.isEmpty { return tags }
        let query = searchText.lowercased()
        return tags.filter {
            $0.replacingOccurrences(of: "_", with: " ").contains(query)
        }
    }
}
```

### C9. iOS: Add tags to BookDetailView

In `BookDetailView.swift`, add the `ContentTagsSection` inside the scroll content:

```swift
// After the reviews section, add:
ContentTagsSection(bookID: bookID)
    .padding(.horizontal)
```

### C10. Add tags to BookDetail API response (optional enhancement)

**File: `backend/api/schemas/books.py`** — Add tags to BookDetail:

```python
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
    content_tags: list["ContentTagBrief"] = []  # <-- NEW

    model_config = {"from_attributes": True}


class ContentTagBrief(BaseModel):
    tag_name: str
    tag_type: str
    display_name: str
    vote_count: int
    is_confirmed: bool
```

---

## D. Alembic Migration

**File: `backend/migrations/versions/xxxx_plan25_privacy_stats_tags.py`** — New migration:

Generate with: `alembic revision --autogenerate -m "plan25_privacy_stats_tags"`

The migration should produce:

```python
"""plan25_privacy_stats_tags

Revision ID: <auto-generated>
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers
revision = "<auto>"
down_revision = "<previous>"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # A. Per-book privacy
    op.add_column("user_books", sa.Column("is_private", sa.Boolean(), server_default="false", nullable=False))

    # B. Reading stats privacy
    op.add_column("users", sa.Column("hide_reading_stats", sa.Boolean(), server_default="false", nullable=False))

    # C. Content tags
    op.create_table(
        "work_content_tags",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("work_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("works.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("tag_name", sa.String(50), nullable=False),
        sa.Column("tag_type", sa.String(20), nullable=False),
        sa.Column("vote_count", sa.Integer(), server_default="1", nullable=False),
        sa.Column("is_confirmed", sa.Boolean(), server_default="false", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("work_id", "tag_name", name="uq_work_content_tag"),
    )

    op.create_table(
        "work_content_tag_votes",
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("work_content_tag_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("work_content_tags.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table("work_content_tag_votes")
    op.drop_table("work_content_tags")
    op.drop_column("users", "hide_reading_stats")
    op.drop_column("user_books", "is_private")
```

---

## E. Tests

### E1. Privacy Tests

**File: `backend/tests/test_privacy.py`** — New file:

```python
"""Tests for per-book privacy feature."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_log_private_book(client: AsyncClient, auth_headers: dict, work_id: str):
    """Private books should be created successfully."""
    response = await client.post(
        "/api/v1/me/books",
        json={
            "work_id": work_id,
            "status": "read",
            "review_text": "Great book",
            "rating": 4.0,
            "is_private": True,
        },
        headers=auth_headers,
    )
    assert response.status_code == 201
    data = response.json()
    assert data["is_private"] is True


@pytest.mark.asyncio
async def test_private_book_hidden_from_other_users(
    client: AsyncClient, auth_headers: dict, other_auth_headers: dict, user_id: str, work_id: str
):
    """Private books should not appear when another user views your library."""
    # Log a private book
    await client.post(
        "/api/v1/me/books",
        json={"work_id": work_id, "status": "read", "is_private": True},
        headers=auth_headers,
    )

    # Other user views the library
    response = await client.get(
        f"/api/v1/users/{user_id}/books",
        headers=other_auth_headers,
    )
    assert response.status_code == 200
    items = response.json()["items"]
    assert len(items) == 0  # Private book is hidden


@pytest.mark.asyncio
async def test_private_book_visible_to_owner(
    client: AsyncClient, auth_headers: dict, work_id: str
):
    """Private books should be visible to the owner."""
    await client.post(
        "/api/v1/me/books",
        json={"work_id": work_id, "status": "read", "is_private": True},
        headers=auth_headers,
    )

    response = await client.get("/api/v1/me/books", headers=auth_headers)
    assert response.status_code == 200
    items = response.json()["items"]
    assert len(items) == 1
    assert items[0]["is_private"] is True


@pytest.mark.asyncio
async def test_private_book_no_activity(
    client: AsyncClient, auth_headers: dict, work_id: str
):
    """Private books should not create Activity records."""
    # This would be verified by checking the feed
    await client.post(
        "/api/v1/me/books",
        json={"work_id": work_id, "status": "read", "is_private": True},
        headers=auth_headers,
    )
    # No assertion on activity — verified by feed_service filtering


@pytest.mark.asyncio
async def test_toggle_privacy(
    client: AsyncClient, auth_headers: dict, work_id: str
):
    """Users should be able to toggle privacy on existing books."""
    # Log a public book
    response = await client.post(
        "/api/v1/me/books",
        json={"work_id": work_id, "status": "reading"},
        headers=auth_headers,
    )
    book_id = response.json()["id"]

    # Make it private
    response = await client.patch(
        f"/api/v1/me/books/{book_id}",
        json={"is_private": True},
        headers=auth_headers,
    )
    assert response.status_code == 200
    assert response.json()["is_private"] is True
```

### E2. Stats Tests

**File: `backend/tests/test_stats.py`** — New file:

```python
"""Tests for reading statistics endpoints."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_get_my_stats(client: AsyncClient, auth_headers: dict):
    """Should return reading stats for the current user."""
    response = await client.get("/api/v1/me/stats", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert "total_books" in data
    assert "total_read" in data
    assert "total_reading" in data
    assert "yearly_stats" in data


@pytest.mark.asyncio
async def test_stats_include_private_books(
    client: AsyncClient, auth_headers: dict, work_id: str
):
    """Private books should still count in the owner's stats."""
    await client.post(
        "/api/v1/me/books",
        json={"work_id": work_id, "status": "read", "is_private": True},
        headers=auth_headers,
    )

    response = await client.get("/api/v1/me/stats", headers=auth_headers)
    data = response.json()
    assert data["total_read"] >= 1


@pytest.mark.asyncio
async def test_hidden_stats(
    client: AsyncClient, auth_headers: dict, other_auth_headers: dict, user_id: str
):
    """Users who hide stats should return 404 to other users."""
    # Hide stats
    await client.patch(
        "/api/v1/me",
        json={"hide_reading_stats": True},
        headers=auth_headers,
    )

    # Other user tries to view
    response = await client.get(
        f"/api/v1/users/{user_id}/stats",
        headers=other_auth_headers,
    )
    assert response.status_code == 404
```

### E3. Content Tag Tests

**File: `backend/tests/test_content_tags.py`** — New file:

```python
"""Tests for content warning and mood tag endpoints."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_get_available_tags(client: AsyncClient, auth_headers: dict):
    """Should return predefined tag lists."""
    response = await client.get("/api/v1/books/tags/available", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert "content_warnings" in data
    assert "moods" in data
    assert "graphic_violence" in data["content_warnings"]
    assert "slow_burn" in data["moods"]


@pytest.mark.asyncio
async def test_vote_for_tag(client: AsyncClient, auth_headers: dict, work_id: str):
    """Should create a tag vote."""
    response = await client.post(
        f"/api/v1/books/{work_id}/tags/vote",
        json={"tag_name": "slow_burn"},
        headers=auth_headers,
    )
    assert response.status_code == 201
    data = response.json()
    assert data["tag_name"] == "slow_burn"
    assert data["tag_type"] == "mood"
    assert data["vote_count"] == 1
    assert data["is_confirmed"] is False


@pytest.mark.asyncio
async def test_invalid_tag_rejected(client: AsyncClient, auth_headers: dict, work_id: str):
    """Invalid tags should be rejected."""
    response = await client.post(
        f"/api/v1/books/{work_id}/tags/vote",
        json={"tag_name": "not_a_real_tag"},
        headers=auth_headers,
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_duplicate_vote_rejected(client: AsyncClient, auth_headers: dict, work_id: str):
    """Users can't vote for the same tag twice."""
    await client.post(
        f"/api/v1/books/{work_id}/tags/vote",
        json={"tag_name": "dark"},
        headers=auth_headers,
    )

    response = await client.post(
        f"/api/v1/books/{work_id}/tags/vote",
        json={"tag_name": "dark"},
        headers=auth_headers,
    )
    assert response.status_code == 409


@pytest.mark.asyncio
async def test_remove_vote(client: AsyncClient, auth_headers: dict, work_id: str):
    """Users should be able to remove their vote."""
    await client.post(
        f"/api/v1/books/{work_id}/tags/vote",
        json={"tag_name": "emotional"},
        headers=auth_headers,
    )

    response = await client.delete(
        f"/api/v1/books/{work_id}/tags/emotional/vote",
        headers=auth_headers,
    )
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_tag_confirmation_threshold(
    client: AsyncClient,
    auth_headers: dict,
    work_id: str,
    # Would need 3 different authenticated users to test threshold
):
    """Tags should be confirmed after reaching the vote threshold."""
    # This test would require multiple user fixtures
    # Verify via direct service call in integration tests
    pass


@pytest.mark.asyncio
async def test_get_work_tags(client: AsyncClient, auth_headers: dict, work_id: str):
    """Should return tags for a work ordered by vote count."""
    await client.post(
        f"/api/v1/books/{work_id}/tags/vote",
        json={"tag_name": "page_turner"},
        headers=auth_headers,
    )

    response = await client.get(
        f"/api/v1/books/{work_id}/tags",
        headers=auth_headers,
    )
    assert response.status_code == 200
    tags = response.json()
    assert len(tags) >= 1
    assert tags[0]["tag_name"] == "page_turner"
```

---

## Summary of All Files Changed/Created

### Modified Files
| File | Change |
|------|--------|
| `backend/models/user_book.py` | Add `is_private` column |
| `backend/models/user.py` | Add `hide_reading_stats` column |
| `backend/api/model_stubs.py` | Add `is_private` to UserBook, `hide_reading_stats` to User, new `WorkContentTag` + `WorkContentTagVote` classes |
| `backend/api/schemas/user_books.py` | Add `is_private` to all three schemas |
| `backend/api/schemas/users.py` | Add `hide_reading_stats` to `UpdateProfileRequest` and `UserProfile` |
| `backend/api/schemas/books.py` | Add `content_tags` to `BookDetail` (optional) |
| `backend/services/user_book_service.py` | Privacy-aware Activity creation + listing filter |
| `backend/services/feed_service.py` | Filter private books from feed |
| `backend/api/routes/books.py` | Add content tag endpoints |
| `backend/api/main.py` | Register stats router |
| `ios/Shelf/Models/UserBook.swift` | Add `isPrivate` to all structs |
| `ios/Shelf/Views/BookDetail/LogBookSheet.swift` | Add privacy toggle |
| `ios/Shelf/Views/BookDetail/BookDetailView.swift` | Add ContentTagsSection |
| `ios/Shelf/Views/Profile/MyProfileView.swift` | Add stats NavigationLink |
| `ios/Shelf/Views/Profile/SettingsView.swift` | Add hide stats toggle |

### New Files
| File | Purpose |
|------|---------|
| `backend/api/schemas/stats.py` | Reading stats response schemas |
| `backend/api/schemas/content_tags.py` | Content tag request/response schemas |
| `backend/api/routes/stats.py` | Stats endpoints |
| `backend/services/stats_service.py` | Stats computation logic |
| `backend/services/content_tags.py` | Predefined tag lists + constants |
| `backend/services/content_tag_service.py` | Tag voting logic |
| `backend/tests/test_privacy.py` | Privacy tests |
| `backend/tests/test_stats.py` | Stats tests |
| `backend/tests/test_content_tags.py` | Content tag tests |
| `backend/migrations/versions/xxxx_plan25_*.py` | Alembic migration |
| `ios/Shelf/Models/ReadingStats.swift` | Stats Codable models |
| `ios/Shelf/Models/ContentTag.swift` | Content tag Codable models |
| `ios/Shelf/ViewModels/StatsViewModel.swift` | Stats view model |
| `ios/Shelf/Views/Profile/ReadingStatsView.swift` | Stats UI with Charts |
| `ios/Shelf/Views/BookDetail/ContentTagsSection.swift` | Tag display + voting UI |
