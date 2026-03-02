"""Nightly sync: fetch OL Recent Changes API and upsert new/updated books.

Runs at 3am UTC via Railway cron. Tracks progress in pipeline_sync_state table.

Usage:
    python -m pipeline.sync.nightly_sync
"""

from __future__ import annotations

import asyncio
import logging
from datetime import date, datetime, timedelta, timezone

import httpx
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from pipeline.config import PipelineConfig, load_config
from pipeline.db import create_async_session_factory
from pipeline.import_ol.helpers import extract_ol_id, extract_text_value, extract_year, generate_uuid
from pipeline.import_ol.parse_works import _extract_author_ol_ids, _extract_cover_ids
from pipeline.models import Author, SyncState, Work, WorkAuthor

logger = logging.getLogger(__name__)

RECENT_CHANGES_URL = "https://openlibrary.org/recentchanges"
RELEVANT_KINDS = {"add-book", "edit-book", "add-work", "edit-work", "add-author", "edit-author"}


async def get_sync_state(session: AsyncSession) -> SyncState | None:
    """Get the current sync state for nightly OL sync."""
    result = await session.execute(
        select(SyncState).where(SyncState.sync_type == "nightly_ol")
    )
    return result.scalar_one_or_none()


async def update_sync_state(
    session: AsyncSession, synced_date: str, offset: int
) -> None:
    """Update (or create) the sync state record."""
    state = await get_sync_state(session)
    if state is None:
        state = SyncState(sync_type="nightly_ol", last_synced_date=synced_date, last_synced_offset=offset)
        session.add(state)
    else:
        state.last_synced_date = synced_date
        state.last_synced_offset = offset
        state.updated_at = datetime.now(timezone.utc)
    await session.commit()


async def fetch_recent_changes(
    client: httpx.AsyncClient,
    target_date: str,
    limit: int = 1000,
    offset: int = 0,
) -> list[dict]:
    """Fetch a page of recent changes from OL for a specific date."""
    url = f"{RECENT_CHANGES_URL}/{target_date}.json"
    params = {"limit": limit, "offset": offset}
    resp = await client.get(url, params=params)
    resp.raise_for_status()
    return resp.json()


async def fetch_ol_record(client: httpx.AsyncClient, key: str) -> dict | None:
    """Fetch a full record from OL by key (e.g., /works/OL123W)."""
    url = f"https://openlibrary.org{key}.json"
    try:
        resp = await client.get(url)
        if resp.status_code == 200:
            return resp.json()
    except httpx.HTTPError:
        logger.debug("Failed to fetch OL record %s", key)
    return None


async def upsert_work_from_ol(session: AsyncSession, data: dict) -> None:
    """Upsert a work record from OL API response."""
    key = data.get("key", "")
    ol_id = extract_ol_id(key)
    work_uuid = generate_uuid(ol_id)

    title = data.get("title", "").strip()
    if not title:
        return

    subjects_raw = data.get("subjects", [])
    subjects = (
        [s.strip() for s in subjects_raw if isinstance(s, str) and s.strip()]
        if isinstance(subjects_raw, list)
        else None
    )

    now = datetime.now(timezone.utc)

    await session.execute(
        text("""
            INSERT INTO works (id, title, description, first_published_year,
                             open_library_work_id, subjects, cover_ol_ids, created_at, updated_at)
            VALUES (:id, :title, :description, :first_published_year,
                    :open_library_work_id, :subjects, :cover_ol_ids, :created_at, :updated_at)
            ON CONFLICT (open_library_work_id) DO UPDATE SET
                title = EXCLUDED.title,
                description = COALESCE(EXCLUDED.description, works.description),
                first_published_year = COALESCE(EXCLUDED.first_published_year, works.first_published_year),
                subjects = COALESCE(EXCLUDED.subjects, works.subjects),
                cover_ol_ids = COALESCE(EXCLUDED.cover_ol_ids, works.cover_ol_ids),
                updated_at = EXCLUDED.updated_at
        """),
        {
            "id": str(work_uuid),
            "title": title,
            "description": extract_text_value(data.get("description")),
            "first_published_year": extract_year(data.get("first_publish_date")),
            "open_library_work_id": ol_id,
            "subjects": subjects,
            "cover_ol_ids": _extract_cover_ids(data) or None,
            "created_at": now,
            "updated_at": now,
        },
    )

    # Upsert work-author relationships
    for author_ol_id in _extract_author_ol_ids(data):
        author_uuid = generate_uuid(author_ol_id)
        await session.execute(
            text("""
                INSERT INTO work_authors (work_id, author_id)
                VALUES (:work_id, :author_id)
                ON CONFLICT (work_id, author_id) DO NOTHING
            """),
            {"work_id": str(work_uuid), "author_id": str(author_uuid)},
        )


async def upsert_author_from_ol(session: AsyncSession, data: dict) -> None:
    """Upsert an author record from OL API response."""
    key = data.get("key", "")
    ol_id = extract_ol_id(key)
    author_uuid = generate_uuid(ol_id)

    name = data.get("name", "").strip()
    if not name:
        return

    now = datetime.now(timezone.utc)

    await session.execute(
        text("""
            INSERT INTO authors (id, name, bio, open_library_author_id, created_at, updated_at)
            VALUES (:id, :name, :bio, :open_library_author_id, :created_at, :updated_at)
            ON CONFLICT (open_library_author_id) DO UPDATE SET
                name = EXCLUDED.name,
                bio = COALESCE(EXCLUDED.bio, authors.bio),
                updated_at = EXCLUDED.updated_at
        """),
        {
            "id": str(author_uuid),
            "name": name,
            "bio": extract_text_value(data.get("bio")),
            "open_library_author_id": ol_id,
            "created_at": now,
            "updated_at": now,
        },
    )


async def sync_day(
    session: AsyncSession,
    client: httpx.AsyncClient,
    target_date: str,
    start_offset: int = 0,
    limit: int = 1000,
) -> int:
    """Sync all relevant changes for a single day. Returns total changes processed."""
    offset = start_offset
    total = 0

    while True:
        changes = await fetch_recent_changes(client, target_date, limit=limit, offset=offset)
        if not changes:
            break

        for change in changes:
            kind = change.get("kind", "")
            if kind not in RELEVANT_KINDS:
                continue

            changes_list = change.get("changes", [])
            for c in changes_list:
                key = c.get("key", "")
                if not key:
                    continue

                record = await fetch_ol_record(client, key)
                if record is None:
                    continue

                if "/works/" in key:
                    await upsert_work_from_ol(session, record)
                elif "/authors/" in key:
                    await upsert_author_from_ol(session, record)

                total += 1

        await session.commit()
        await update_sync_state(session, target_date, offset + len(changes))

        if len(changes) < limit:
            break
        offset += limit

    return total


async def run_nightly_sync(config: PipelineConfig | None = None) -> None:
    """Run the nightly sync from OL Recent Changes API.

    Syncs day-by-day from the last synced date up to yesterday.
    """
    if config is None:
        config = load_config()

    session_factory = create_async_session_factory(config)
    yesterday = (datetime.now(timezone.utc) - timedelta(days=1)).strftime("%Y/%m/%d")

    async with session_factory() as session:
        state = await get_sync_state(session)

        if state and state.last_synced_date:
            # Parse last synced date and advance to the next day
            parts = state.last_synced_date.split("/")
            last_date = date(int(parts[0]), int(parts[1]), int(parts[2]))
            start_date = last_date + timedelta(days=1)
        else:
            # First run: start from yesterday
            start_date = datetime.now(timezone.utc).date() - timedelta(days=1)

        current = start_date
        end_date_parts = yesterday.split("/")
        end = date(int(end_date_parts[0]), int(end_date_parts[1]), int(end_date_parts[2]))

        async with httpx.AsyncClient(timeout=30.0) as client:
            while current <= end:
                target = current.strftime("%Y/%m/%d")
                logger.info("Syncing changes for %s", target)
                count = await sync_day(session, client, target)
                logger.info("  Synced %d records for %s", count, target)
                current += timedelta(days=1)


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    asyncio.run(run_nightly_sync())


if __name__ == "__main__":
    main()
