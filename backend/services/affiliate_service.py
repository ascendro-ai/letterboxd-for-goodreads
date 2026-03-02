from __future__ import annotations

from urllib.parse import quote_plus
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession


async def get_best_isbn_for_work(db: AsyncSession, work_id: UUID) -> str | None:
    """Query editions for a work and return the best ISBN available.

    Preference order:
      1. ISBN-13 from an English edition
      2. ISBN-10 from an English edition
      3. ISBN-13 from any edition
      4. ISBN-10 from any edition

    Returns None if no edition has any ISBN.
    """
    from backend.api.model_stubs import Edition

    # Try English editions with ISBN-13 first
    result = await db.execute(
        select(Edition.isbn_13)
        .where(
            Edition.work_id == work_id,
            Edition.isbn_13.isnot(None),
            Edition.isbn_13 != "",
            Edition.language.in_(["en", "eng", "English"]),
        )
        .order_by(Edition.publish_date.desc().nulls_last())
        .limit(1)
    )
    isbn = result.scalar_one_or_none()
    if isbn:
        return isbn

    # Try English editions with ISBN-10
    result = await db.execute(
        select(Edition.isbn_10)
        .where(
            Edition.work_id == work_id,
            Edition.isbn_10.isnot(None),
            Edition.isbn_10 != "",
            Edition.language.in_(["en", "eng", "English"]),
        )
        .order_by(Edition.publish_date.desc().nulls_last())
        .limit(1)
    )
    isbn = result.scalar_one_or_none()
    if isbn:
        return isbn

    # Try any edition with ISBN-13
    result = await db.execute(
        select(Edition.isbn_13)
        .where(
            Edition.work_id == work_id,
            Edition.isbn_13.isnot(None),
            Edition.isbn_13 != "",
        )
        .order_by(Edition.publish_date.desc().nulls_last())
        .limit(1)
    )
    isbn = result.scalar_one_or_none()
    if isbn:
        return isbn

    # Try any edition with ISBN-10
    result = await db.execute(
        select(Edition.isbn_10)
        .where(
            Edition.work_id == work_id,
            Edition.isbn_10.isnot(None),
            Edition.isbn_10 != "",
        )
        .order_by(Edition.publish_date.desc().nulls_last())
        .limit(1)
    )
    isbn = result.scalar_one_or_none()
    if isbn:
        return isbn

    return None


def generate_bookshop_url(
    isbn: str | None,
    title: str,
    affiliate_id: str,
) -> str | None:
    """Generate a Bookshop.org affiliate URL.

    - If affiliate_id is empty/missing, returns None (feature disabled).
    - If ISBN is available, returns a direct product link.
    - If no ISBN but title is available, returns a search URL.
    """
    if not affiliate_id:
        return None

    if isbn:
        return f"https://bookshop.org/a/{affiliate_id}/{isbn}"

    if title:
        encoded_title = quote_plus(title)
        return f"https://bookshop.org/a/{affiliate_id}?q={encoded_title}"

    return None
