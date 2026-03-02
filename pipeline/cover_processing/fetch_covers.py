"""Cover fetch orchestrator: OL covers → Google Books fallback → process → upload.

Usage:
    python -m pipeline.cover_processing.fetch_covers
"""

from __future__ import annotations

import asyncio
import logging
from typing import Any

import httpx
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from pipeline.config import PipelineConfig, load_config
from pipeline.cover_processing.format import convert_to_webp
from pipeline.cover_processing.resize import generate_variants
from pipeline.cover_processing.upload_r2 import R2Uploader
from pipeline.db import create_async_session_factory
from pipeline.models import Edition, Work

logger = logging.getLogger(__name__)

# OL returns tiny 1x1 placeholder images for missing covers — anything under 1KB is not a real cover.
MIN_IMAGE_BYTES = 1024


async def fetch_ol_cover_by_id(
    client: httpx.AsyncClient, cover_id: str
) -> bytes | None:
    """Fetch a cover image from OL by cover ID."""
    url = f"https://covers.openlibrary.org/b/id/{cover_id}-L.jpg"
    try:
        resp = await client.get(url, follow_redirects=True)
        if resp.status_code == 200 and len(resp.content) >= MIN_IMAGE_BYTES:
            return resp.content
    except httpx.HTTPError:
        logger.debug("Failed to fetch OL cover %s", cover_id)
    return None


async def fetch_ol_cover_by_olid(
    client: httpx.AsyncClient, ol_work_id: str
) -> bytes | None:
    """Fetch a cover image from OL by work OLID."""
    url = f"https://covers.openlibrary.org/b/olid/{ol_work_id}-L.jpg"
    try:
        resp = await client.get(url, follow_redirects=True)
        if resp.status_code == 200 and len(resp.content) >= MIN_IMAGE_BYTES:
            return resp.content
    except httpx.HTTPError:
        logger.debug("Failed to fetch OL cover by OLID %s", ol_work_id)
    return None


async def fetch_google_books_cover(
    client: httpx.AsyncClient, isbn: str, api_key: str
) -> bytes | None:
    """Fetch a cover image from Google Books API by ISBN."""
    if not api_key:
        return None
    url = f"https://www.googleapis.com/books/v1/volumes?q=isbn:{isbn}&key={api_key}"
    try:
        resp = await client.get(url)
        if resp.status_code != 200:
            return None
        data = resp.json()
        items = data.get("items", [])
        if not items:
            return None
        image_links = items[0].get("volumeInfo", {}).get("imageLinks", {})
        thumb_url = image_links.get("thumbnail") or image_links.get("smallThumbnail")
        if not thumb_url:
            return None
        # Get the larger version
        large_url = thumb_url.replace("zoom=1", "zoom=3")
        img_resp = await client.get(large_url, follow_redirects=True)
        if img_resp.status_code == 200 and len(img_resp.content) >= MIN_IMAGE_BYTES:
            return img_resp.content
    except (httpx.HTTPError, KeyError, ValueError):
        logger.debug("Failed to fetch Google Books cover for ISBN %s", isbn)
    return None


async def get_isbn_for_work(session: AsyncSession, work_id: str) -> str | None:
    """Get the first available ISBN for a work from its editions."""
    result = await session.execute(
        select(Edition.isbn_13, Edition.isbn_10)
        .where(Edition.work_id == work_id)
        .limit(1)
    )
    row = result.first()
    if row:
        return row.isbn_13 or row.isbn_10
    return None


async def process_single_work(
    work: Any,
    session: AsyncSession,
    client: httpx.AsyncClient,
    uploader: R2Uploader,
    config: PipelineConfig,
    semaphore: asyncio.Semaphore,
    google_counter: dict[str, int],
) -> bool:
    """Fetch, process, and upload cover for a single work.

    Cover fetch waterfall:
      1. OL cover IDs (from work record)
      2. OL OLID (work's open_library_work_id)
      3. Google Books ISBN fallback (limited daily)

    Returns True if a cover was found and uploaded.
    """
    async with semaphore:
        image_data: bytes | None = None

        # 1. Try OL cover IDs
        cover_ol_ids = work.cover_ol_ids or []
        for cover_id in cover_ol_ids:
            image_data = await fetch_ol_cover_by_id(client, cover_id)
            if image_data:
                break

        # 2. Try OL OLID
        if not image_data and work.open_library_work_id:
            image_data = await fetch_ol_cover_by_olid(client, work.open_library_work_id)

        # 3. Google Books ISBN fallback
        if not image_data and google_counter["count"] < config.google_books.daily_limit:
            isbn = await get_isbn_for_work(session, str(work.id))
            if isbn:
                google_counter["count"] += 1
                image_data = await fetch_google_books_cover(
                    client, isbn, config.google_books.api_key
                )

        if not image_data:
            return False

        # Convert to WebP and generate variants
        webp_data, content_type = convert_to_webp(image_data)
        variants = generate_variants(webp_data)

        # Upload all variants to R2
        keys = uploader.upload_all_variants(str(work.id), variants, content_type)

        # Update work with the detail variant URL
        detail_key = keys.get("detail", "")
        if detail_key:
            await session.execute(
                update(Work)
                .where(Work.id == work.id)
                .values(cover_image_url=detail_key)
            )
            await session.commit()

        return True


async def run_cover_pipeline(config: PipelineConfig | None = None) -> None:
    """Main cover processing pipeline.

    Queries works with NULL cover_image_url and processes them concurrently.
    """
    if config is None:
        config = load_config()

    session_factory = create_async_session_factory(config)
    uploader = R2Uploader(config.r2)
    semaphore = asyncio.Semaphore(config.cover_concurrency)
    google_counter: dict[str, int] = {"count": 0}

    async with session_factory() as session:
        # Fetch works needing covers
        result = await session.execute(
            select(Work).where(Work.cover_image_url.is_(None)).limit(10_000)
        )
        works = result.scalars().all()
        logger.info("Found %d works needing covers", len(works))

        async with httpx.AsyncClient(timeout=30.0) as client:
            tasks = [
                process_single_work(
                    work, session, client, uploader, config, semaphore, google_counter
                )
                for work in works
            ]
            results = await asyncio.gather(*tasks, return_exceptions=True)

        success = sum(1 for r in results if r is True)
        errors = sum(1 for r in results if isinstance(r, Exception))
        logger.info(
            "Cover pipeline complete: %d succeeded, %d failed, %d no cover found",
            success, errors, len(works) - success - errors,
        )


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    asyncio.run(run_cover_pipeline())


if __name__ == "__main__":
    main()
