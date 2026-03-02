"""
Data export service.

Handles requesting, generating, and retrieving user data exports.
Export files are JSON documents uploaded to R2 with signed download URLs.
"""

from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime, timedelta, timezone
from uuid import UUID

from backend.api.config import get_settings
from backend.api.errors import AppError
from backend.api.model_stubs import (
    ExportRequest,
    Follow,
    Shelf,
    ShelfBook,
    User,
    UserBook,
    Work,
)
from backend.api.schemas.export import ExportStatusResponse
from backend.services.r2_storage import generate_signed_url, upload_to_r2
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

logger = logging.getLogger(__name__)

EXPORT_COOLDOWN_HOURS = 24
SIGNED_URL_EXPIRY_SECONDS = 86400  # 24 hours


async def request_export(db: AsyncSession, user_id: UUID) -> ExportStatusResponse:
    """Request a new data export.

    Rate-limited to 1 export per 24 hours. Kicks off a background task
    to generate the export file.
    """
    # Check for existing pending/processing export in the last 24 hours
    cutoff = datetime.now(timezone.utc) - timedelta(hours=EXPORT_COOLDOWN_HOURS)
    existing = await db.execute(
        select(ExportRequest).where(
            ExportRequest.user_id == user_id,
            ExportRequest.status.in_(["pending", "processing"]),
            ExportRequest.created_at >= cutoff,
        )
    )
    if existing.scalar_one_or_none() is not None:
        raise AppError(
            status_code=429,
            code="EXPORT_RATE_LIMITED",
            message="An export is already in progress. Please wait 24 hours.",
        )

    # Also check for recently completed exports
    recent_completed = await db.execute(
        select(ExportRequest).where(
            ExportRequest.user_id == user_id,
            ExportRequest.status == "completed",
            ExportRequest.created_at >= cutoff,
        )
    )
    if recent_completed.scalar_one_or_none() is not None:
        raise AppError(
            status_code=429,
            code="EXPORT_RATE_LIMITED",
            message="You have already exported your data in the last 24 hours.",
        )

    # Create the export request
    export_request = ExportRequest(
        user_id=user_id,
        status="pending",
    )
    db.add(export_request)
    await db.flush()

    # Kick off the background generation task
    _task = asyncio.create_task(  # noqa: RUF006
        generate_export(export_request.id, user_id)
    )

    return ExportStatusResponse(
        id=export_request.id,
        status="pending",
        file_url=None,
        file_size_bytes=None,
        created_at=export_request.created_at,
        completed_at=None,
        expires_at=None,
    )


async def generate_export(export_request_id: UUID, user_id: UUID) -> None:
    """Background task: generate the export JSON and upload to R2.

    Runs in its own database session since it's a background task.
    """
    settings = get_settings()
    engine = create_async_engine(settings.database_url)
    session_factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with session_factory() as db:
        try:
            # Mark as processing
            export_req = await _get_export_request(db, export_request_id)
            export_req.status = "processing"
            await db.commit()

            # Load user
            user_result = await db.execute(select(User).where(User.id == user_id))
            user = user_result.scalar_one_or_none()
            if user is None:
                raise ValueError(f"User {user_id} not found")

            # Load user_books with work details
            user_books_result = await db.execute(
                select(UserBook).where(UserBook.user_id == user_id)
            )
            user_books = list(user_books_result.scalars().all())

            # Load works for those books
            work_ids = [ub.work_id for ub in user_books]
            works_map: dict[str, Work] = {}
            if work_ids:
                works_result = await db.execute(select(Work).where(Work.id.in_(work_ids)))
                works_map = {str(w.id): w for w in works_result.scalars().all()}

            # Load shelves with their books
            shelves_result = await db.execute(select(Shelf).where(Shelf.user_id == user_id))
            shelves = list(shelves_result.scalars().all())

            # Load shelf_books for all shelves
            shelf_ids = [s.id for s in shelves]
            shelf_books_map: dict[str, list[str]] = {}
            if shelf_ids:
                shelf_books_result = await db.execute(
                    select(ShelfBook).where(ShelfBook.shelf_id.in_(shelf_ids))
                )
                shelf_books = list(shelf_books_result.scalars().all())

                user_book_ids = [sb.user_book_id for sb in shelf_books]
                ub_map: dict[str, UserBook] = {}
                if user_book_ids:
                    ub_result = await db.execute(
                        select(UserBook).where(UserBook.id.in_(user_book_ids))
                    )
                    ub_map = {str(ub.id): ub for ub in ub_result.scalars().all()}

                for sb in shelf_books:
                    sid = str(sb.shelf_id)
                    if sid not in shelf_books_map:
                        shelf_books_map[sid] = []
                    ub = ub_map.get(str(sb.user_book_id))
                    if ub:
                        work = works_map.get(str(ub.work_id))
                        title = work.title if work else "Unknown"
                        shelf_books_map[sid].append(title)

            # Load following
            following_result = await db.execute(select(Follow).where(Follow.follower_id == user_id))
            following_records = list(following_result.scalars().all())
            following_user_ids = [f.following_id for f in following_records]

            following_usernames: list[str] = []
            if following_user_ids:
                following_users_result = await db.execute(
                    select(User).where(User.id.in_(following_user_ids))
                )
                following_usernames = [u.username for u in following_users_result.scalars().all()]

            # Load followers
            followers_result = await db.execute(
                select(Follow).where(Follow.following_id == user_id)
            )
            follower_records = list(followers_result.scalars().all())
            follower_user_ids = [f.follower_id for f in follower_records]

            follower_usernames: list[str] = []
            if follower_user_ids:
                follower_users_result = await db.execute(
                    select(User).where(User.id.in_(follower_user_ids))
                )
                follower_usernames = [u.username for u in follower_users_result.scalars().all()]

            # Build the export JSON
            now = datetime.now(timezone.utc)
            export_data = {
                "exported_at": now.isoformat(),
                "user": {
                    "username": user.username,
                    "display_name": getattr(user, "display_name", None),
                    "bio": getattr(user, "bio", None),
                    "created_at": user.created_at.isoformat() if user.created_at else None,
                },
                "books": [
                    _serialize_user_book(ub, works_map.get(str(ub.work_id))) for ub in user_books
                ],
                "shelves": [
                    {
                        "name": shelf.name,
                        "description": getattr(shelf, "description", None),
                        "is_public": getattr(shelf, "is_public", True),
                        "books": shelf_books_map.get(str(shelf.id), []),
                    }
                    for shelf in shelves
                ],
                "following": following_usernames,
                "followers": follower_usernames,
            }

            # Serialize to JSON bytes
            json_bytes = json.dumps(export_data, indent=2, default=str).encode("utf-8")

            # Upload to R2
            r2_key = f"exports/{user_id}/{export_request_id}.json"
            upload_to_r2(json_bytes, r2_key)

            # Generate signed URL
            signed_url = generate_signed_url(r2_key, SIGNED_URL_EXPIRY_SECONDS)
            expires_at = now + timedelta(seconds=SIGNED_URL_EXPIRY_SECONDS)

            # Update export request
            export_req = await _get_export_request(db, export_request_id)
            export_req.status = "completed"
            export_req.file_url = signed_url
            export_req.file_size_bytes = len(json_bytes)
            export_req.completed_at = now
            export_req.expires_at = expires_at
            await db.commit()

            logger.info(
                "Export %s completed for user %s (%d bytes)",
                export_request_id,
                user_id,
                len(json_bytes),
            )

        except Exception as e:
            logger.error(
                "Export %s failed for user %s: %s",
                export_request_id,
                user_id,
                str(e),
            )
            try:
                export_req = await _get_export_request(db, export_request_id)
                export_req.status = "failed"
                await db.commit()
            except Exception:
                logger.error("Failed to update export request status to failed")
        finally:
            await engine.dispose()


async def get_export_status(db: AsyncSession, user_id: UUID) -> ExportStatusResponse:
    """Return the most recent export request for the user."""
    result = await db.execute(
        select(ExportRequest)
        .where(ExportRequest.user_id == user_id)
        .order_by(ExportRequest.created_at.desc())
        .limit(1)
    )
    export_req = result.scalar_one_or_none()
    if export_req is None:
        raise AppError(
            status_code=404,
            code="NO_EXPORT_FOUND",
            message="No export request found.",
        )

    return ExportStatusResponse(
        id=export_req.id,
        status=export_req.status if isinstance(export_req.status, str) else export_req.status.value,
        file_url=export_req.file_url,
        file_size_bytes=export_req.file_size_bytes,
        created_at=export_req.created_at,
        completed_at=export_req.completed_at,
        expires_at=export_req.expires_at,
    )


async def get_download_url(db: AsyncSession, user_id: UUID, export_id: UUID) -> str:
    """Get the download URL for a completed export.

    Validates ownership and expiry. Regenerates the signed URL if the
    export is still within the 24h window but the URL may have expired.
    """
    result = await db.execute(select(ExportRequest).where(ExportRequest.id == export_id))
    export_req = result.scalar_one_or_none()
    if export_req is None:
        raise AppError(
            status_code=404,
            code="EXPORT_NOT_FOUND",
            message="No export found with the given ID.",
        )

    # Verify ownership
    if str(export_req.user_id) != str(user_id):
        raise AppError(
            status_code=403,
            code="FORBIDDEN",
            message="You do not have access to this export.",
        )

    # Verify status
    status_val = (
        export_req.status if isinstance(export_req.status, str) else export_req.status.value
    )
    if status_val != "completed":
        raise AppError(
            status_code=400,
            code="EXPORT_NOT_READY",
            message="This export is not yet completed.",
        )

    # Verify not expired
    now = datetime.now(timezone.utc)
    if export_req.expires_at and export_req.expires_at.replace(tzinfo=timezone.utc) < now:
        raise AppError(
            status_code=410,
            code="EXPORT_EXPIRED",
            message="This export has expired. Please request a new export.",
        )

    # Regenerate signed URL
    r2_key = f"exports/{user_id}/{export_id}.json"
    new_url = generate_signed_url(r2_key, SIGNED_URL_EXPIRY_SECONDS)

    # Update the stored URL
    export_req.file_url = new_url
    new_expires = now + timedelta(seconds=SIGNED_URL_EXPIRY_SECONDS)
    export_req.expires_at = new_expires
    await db.flush()

    return new_url


def _serialize_user_book(ub: UserBook, work: Work | None) -> dict:
    """Serialize a user_book for the export JSON. No internal IDs exposed."""
    authors_list: list[str] = []
    if work and hasattr(work, "authors") and work.authors:
        authors_list = [a.name for a in work.authors]

    return {
        "title": work.title if work else "Unknown",
        "authors": authors_list,
        "status": ub.status if isinstance(ub.status, str) else ub.status.value,
        "rating": float(ub.rating) if ub.rating is not None else None,
        "review_text": ub.review_text,
        "has_spoilers": ub.has_spoilers,
        "started_at": ub.started_at.isoformat() if ub.started_at else None,
        "finished_at": ub.finished_at.isoformat() if ub.finished_at else None,
        "created_at": ub.created_at.isoformat() if ub.created_at else None,
    }


async def _get_export_request(db: AsyncSession, export_id: UUID) -> ExportRequest:
    """Load an export request by ID."""
    result = await db.execute(select(ExportRequest).where(ExportRequest.id == export_id))
    return result.scalar_one()
