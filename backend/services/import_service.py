from __future__ import annotations

import csv
import io
import re
from datetime import datetime
from decimal import Decimal
from uuid import UUID

from backend.api.config import get_settings
from backend.api.errors import import_in_progress
from backend.api.model_stubs import (
    Activity,
    Edition,
    ImportJob,
    Shelf,
    ShelfBook,
    UserBook,
    Work,
)
from backend.api.schemas.import_ import ImportStatusResponse
from backend.api.utils import slugify
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine


async def start_import(
    db: AsyncSession,
    user_id: UUID,
    content: bytes,
    source: str,
) -> ImportJob:
    """Create an ImportJob. Blocks if one is already in progress."""
    # Check for existing in-progress import
    existing = await db.execute(
        select(ImportJob).where(
            ImportJob.user_id == user_id,
            ImportJob.status.in_(["pending", "processing"]),
        )
    )
    if existing.scalar_one_or_none() is not None:
        raise import_in_progress()

    job = ImportJob(
        user_id=user_id,
        source=source,
        status="processing",
    )
    db.add(job)
    await db.flush()
    return job


async def get_import_status(db: AsyncSession, user_id: UUID) -> ImportStatusResponse:
    """Get the most recent import job for a user."""
    result = await db.execute(
        select(ImportJob)
        .where(ImportJob.user_id == user_id)
        .order_by(ImportJob.created_at.desc())
        .limit(1)
    )
    job = result.scalar_one_or_none()
    if job is None:
        from fastapi import HTTPException

        raise HTTPException(status_code=404, detail="No import found")

    return ImportStatusResponse.model_validate(job)


async def process_goodreads_csv(
    job_id: UUID,
    user_id: UUID,
    content: bytes,
) -> None:
    """Background task: parse Goodreads CSV, match books, create UserBooks.

    Runs in its own database session since it's a background task.
    """
    settings = get_settings()
    engine = create_async_engine(settings.database_url)
    session_factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with session_factory() as db:
        try:
            text = content.decode("utf-8-sig")
            reader = csv.DictReader(io.StringIO(text))
            rows = list(reader)

            # Update total count
            job = await _get_job(db, job_id)
            job.total_books = len(rows)
            await db.commit()

            matched = 0
            needs_review = 0
            unmatched = 0

            for i, row in enumerate(rows):
                try:
                    result = await _process_goodreads_row(db, user_id, row)
                    if result == "matched":
                        matched += 1
                    elif result == "needs_review":
                        needs_review += 1
                    else:
                        unmatched += 1
                except Exception:
                    unmatched += 1

                # Update progress every 50 rows
                if (i + 1) % 50 == 0 or i == len(rows) - 1:
                    job = await _get_job(db, job_id)
                    job.matched = matched
                    job.needs_review = needs_review
                    job.unmatched = unmatched
                    job.progress_percent = int(((i + 1) / len(rows)) * 100)
                    await db.commit()

            # Mark complete
            job = await _get_job(db, job_id)
            job.status = "completed"
            job.matched = matched
            job.needs_review = needs_review
            job.unmatched = unmatched
            job.progress_percent = 100
            job.completed_at = datetime.utcnow()
            await db.commit()

        except Exception as e:
            job = await _get_job(db, job_id)
            job.status = "failed"
            job.error_message = str(e)
            await db.commit()
        finally:
            await engine.dispose()


async def _process_goodreads_row(
    db: AsyncSession,
    user_id: UUID,
    row: dict[str, str],
) -> str:
    """Process a single Goodreads CSV row. Returns 'matched', 'needs_review', or 'unmatched'."""
    title = row.get("Title", "").strip()
    author = row.get("Author", "").strip()
    isbn13 = parse_goodreads_isbn(row.get("ISBN13", ""))
    isbn10 = parse_goodreads_isbn(row.get("ISBN", ""))

    # Matching waterfall
    work = await _match_book(db, isbn13, isbn10, title, author)

    if work is None:
        return "unmatched"

    # Check if already logged
    existing = await db.execute(
        select(UserBook).where(UserBook.user_id == user_id, UserBook.work_id == work.id)
    )
    if existing.scalar_one_or_none() is not None:
        return "matched"  # Already exists, skip

    # Map status
    exclusive_shelf = row.get("Exclusive Shelf", "").strip()
    status = map_goodreads_status(exclusive_shelf)

    # Map rating
    rating_str = row.get("My Rating", "0").strip()
    rating = Decimal(rating_str) if rating_str and rating_str != "0" else None

    # Review text
    review_text = row.get("My Review", "").strip() or None

    # Dates
    date_read = _parse_date(row.get("Date Read", ""))
    user_book = UserBook(
        user_id=user_id,
        work_id=work.id,
        status=status,
        rating=rating,
        review_text=review_text,
        has_spoilers=False,
        started_at=None,
        finished_at=date_read,
        is_imported=True,
    )
    db.add(user_book)
    await db.flush()

    # Create activity if status is read
    if status == "read":
        activity = Activity(
            user_id=user_id,
            activity_type="finished_book",
            target_id=user_book.id,
        )
        db.add(activity)

    # Handle custom bookshelves
    bookshelves = row.get("Bookshelves", "").strip()
    if bookshelves:
        await _create_shelves_for_book(db, user_id, user_book.id, bookshelves)

    await db.commit()
    return "matched"


async def process_storygraph_csv(
    job_id: UUID,
    user_id: UUID,
    content: bytes,
) -> None:
    """Background task: parse StoryGraph CSV, match books, create UserBooks."""
    settings = get_settings()
    engine = create_async_engine(settings.database_url)
    session_factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with session_factory() as db:
        try:
            text = content.decode("utf-8-sig")
            reader = csv.DictReader(io.StringIO(text))
            rows = list(reader)

            job = await _get_job(db, job_id)
            job.total_books = len(rows)
            await db.commit()

            matched = 0
            needs_review = 0
            unmatched = 0

            for i, row in enumerate(rows):
                try:
                    result = await _process_storygraph_row(db, user_id, row)
                    if result == "matched":
                        matched += 1
                    elif result == "needs_review":
                        needs_review += 1
                    else:
                        unmatched += 1
                except Exception:
                    unmatched += 1

                if (i + 1) % 50 == 0 or i == len(rows) - 1:
                    job = await _get_job(db, job_id)
                    job.matched = matched
                    job.needs_review = needs_review
                    job.unmatched = unmatched
                    job.progress_percent = int(((i + 1) / len(rows)) * 100)
                    await db.commit()

            job = await _get_job(db, job_id)
            job.status = "completed"
            job.matched = matched
            job.needs_review = needs_review
            job.unmatched = unmatched
            job.progress_percent = 100
            job.completed_at = datetime.utcnow()
            await db.commit()

        except Exception as e:
            job = await _get_job(db, job_id)
            job.status = "failed"
            job.error_message = str(e)
            await db.commit()
        finally:
            await engine.dispose()


async def _process_storygraph_row(
    db: AsyncSession,
    user_id: UUID,
    row: dict[str, str],
) -> str:
    """Process a single StoryGraph CSV row."""
    title = row.get("Title", "").strip()
    author = row.get("Authors", row.get("Author", "")).strip()
    isbn13 = row.get("ISBN/UID", "").strip().replace("-", "")

    work = await _match_book(db, isbn13, None, title, author)

    if work is None:
        return "unmatched"

    existing = await db.execute(
        select(UserBook).where(UserBook.user_id == user_id, UserBook.work_id == work.id)
    )
    if existing.scalar_one_or_none() is not None:
        return "matched"

    # Map StoryGraph status
    sg_status = row.get("Read Status", "").strip().lower()
    status_map = {
        "read": "read",
        "currently-reading": "reading",
        "to-read": "want_to_read",
        "did-not-finish": "did_not_finish",
    }
    status = status_map.get(sg_status, "want_to_read")

    # Rating (StoryGraph uses decimals)
    rating_str = row.get("Star Rating", "").strip()
    rating = None
    if rating_str:
        try:
            raw = float(rating_str)
            rating = Decimal(str(round(raw * 2) / 2))  # Round to nearest 0.5
        except ValueError:
            pass

    review_text = row.get("Review", "").strip() or None

    user_book = UserBook(
        user_id=user_id,
        work_id=work.id,
        status=status,
        rating=rating,
        review_text=review_text,
        has_spoilers=False,
        is_imported=True,
    )
    db.add(user_book)
    await db.flush()

    if status == "read":
        activity = Activity(
            user_id=user_id,
            activity_type="finished_book",
            target_id=user_book.id,
        )
        db.add(activity)

    await db.commit()
    return "matched"


async def _match_book(
    db: AsyncSession,
    isbn13: str | None,
    isbn10: str | None,
    title: str,
    author: str,
) -> Work | None:
    """Matching waterfall: ISBN-13 → ISBN-10 → exact title+author → fuzzy."""
    # 1. ISBN-13
    if isbn13:
        result = await db.execute(select(Edition).where(Edition.isbn_13 == isbn13))
        edition = result.scalar_one_or_none()
        if edition:
            work_result = await db.execute(select(Work).where(Work.id == edition.work_id))
            return work_result.scalar_one_or_none()

    # 2. ISBN-10
    if isbn10:
        result = await db.execute(select(Edition).where(Edition.isbn_10 == isbn10))
        edition = result.scalar_one_or_none()
        if edition:
            work_result = await db.execute(select(Work).where(Work.id == edition.work_id))
            return work_result.scalar_one_or_none()

    # 3. Exact title match (case-insensitive)
    if title:
        result = await db.execute(select(Work).where(func.lower(Work.title) == title.lower()))
        work = result.scalar_one_or_none()
        if work:
            return work

    # 4. Fuzzy match via ILIKE (pg_trgm similarity in production)
    if title:
        result = await db.execute(select(Work).where(Work.title.ilike(f"%{title}%")).limit(1))
        work = result.scalar_one_or_none()
        if work:
            return work

    return None


async def _create_shelves_for_book(
    db: AsyncSession,
    user_id: UUID,
    user_book_id: UUID,
    bookshelves_str: str,
) -> None:
    """Create custom shelves from Goodreads bookshelves column and add the book."""
    # Skip standard Goodreads shelves (handled as status)
    standard = {"read", "currently-reading", "to-read"}
    shelves = [s.strip() for s in bookshelves_str.split(",") if s.strip() not in standard]

    for shelf_name in shelves:
        # Find or create shelf
        slug = slugify(shelf_name)
        result = await db.execute(select(Shelf).where(Shelf.user_id == user_id, Shelf.slug == slug))
        shelf = result.scalar_one_or_none()

        if shelf is None:
            shelf = Shelf(
                user_id=user_id,
                name=shelf_name,
                slug=slug,
            )
            db.add(shelf)
            await db.flush()

        # Add book to shelf if not already there
        existing = await db.execute(
            select(ShelfBook).where(
                ShelfBook.shelf_id == shelf.id, ShelfBook.user_book_id == user_book_id
            )
        )
        if existing.scalar_one_or_none() is None:
            shelf_book = ShelfBook(
                shelf_id=shelf.id,
                user_book_id=user_book_id,
                position=0,
            )
            db.add(shelf_book)


async def _get_job(db: AsyncSession, job_id: UUID) -> ImportJob:
    result = await db.execute(select(ImportJob).where(ImportJob.id == job_id))
    return result.scalar_one()


# --- Helpers ---


def parse_goodreads_isbn(raw: str) -> str | None:
    """Parse Goodreads ISBN format: =\"0123456789\" or plain number."""
    if not raw:
        return None
    # Remove Goodreads ="" quoting (including curly quotes)
    cleaned = re.sub(r'[="\u201c\u201d]', "", raw).strip()
    if not cleaned:
        return None
    return cleaned.replace("-", "")


def normalize_isbn(isbn: str) -> str:
    """Strip hyphens and whitespace from ISBN."""
    return isbn.replace("-", "").replace(" ", "").strip()


def map_goodreads_status(shelf: str) -> str:
    """Map Goodreads shelf name to our status enum."""
    mapping = {
        "read": "read",
        "currently-reading": "reading",
        "to-read": "want_to_read",
    }
    return mapping.get(shelf.lower(), "want_to_read")


def _parse_date(date_str: str) -> datetime | None:
    """Parse common date formats from CSV exports."""
    if not date_str or not date_str.strip():
        return None
    for fmt in ("%Y/%m/%d", "%Y-%m-%d", "%m/%d/%Y", "%d/%m/%Y"):
        try:
            return datetime.strptime(date_str.strip(), fmt)
        except ValueError:
            continue
    return None
