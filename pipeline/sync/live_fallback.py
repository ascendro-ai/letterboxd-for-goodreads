"""Live fallback: on-demand search and import for books not yet in local DB.

Used when a user searches for a book not yet in our catalog (cache miss).
Called by the backend search endpoint when local DB has no results.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

import httpx
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from pipeline.import_ol.helpers import extract_ol_id, extract_text_value, extract_year, generate_uuid
from pipeline.import_ol.parse_works import _extract_author_ol_ids, _extract_cover_ids

logger = logging.getLogger(__name__)

OL_SEARCH_URL = "https://openlibrary.org/search.json"
OL_ISBN_URL = "https://openlibrary.org/isbn"


class LiveFallback:
    """On-demand OL API search and import for missing books."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def search_and_import(
        self,
        query: str | None = None,
        isbn: str | None = None,
    ) -> list[dict[str, Any]]:
        """Search OL and import matching works into local DB.

        Tries ISBN lookup first if provided, otherwise searches by query.
        Returns list of work dicts suitable for API response.
        """
        async with httpx.AsyncClient(timeout=15.0) as client:
            if isbn:
                works = await self._search_by_isbn(client, isbn)
            elif query:
                works = await self._search_by_query(client, query)
            else:
                return []

            for work_data in works:
                await self._upsert_work(work_data)
            await self._session.commit()

            return works

    async def _search_by_isbn(
        self, client: httpx.AsyncClient, isbn: str
    ) -> list[dict[str, Any]]:
        """Look up a book by ISBN via OL ISBN API."""
        url = f"{OL_ISBN_URL}/{isbn}.json"
        try:
            resp = await client.get(url, follow_redirects=True)
            if resp.status_code != 200:
                return []
            data = resp.json()

            # ISBN API returns an edition — resolve to its work
            works = data.get("works", [])
            if not works:
                return []
            work_key = works[0].get("key", "")
            if not work_key:
                return []

            work_resp = await client.get(f"https://openlibrary.org{work_key}.json")
            if work_resp.status_code != 200:
                return []
            return [self._parse_ol_work(work_resp.json())]
        except (httpx.HTTPError, ValueError, KeyError):
            return []

    async def _search_by_query(
        self, client: httpx.AsyncClient, query: str
    ) -> list[dict[str, Any]]:
        """Search OL by query string."""
        try:
            resp = await client.get(OL_SEARCH_URL, params={"q": query, "limit": 10})
            if resp.status_code != 200:
                return []
            data = resp.json()
            docs = data.get("docs", [])
            return [self._parse_search_doc(doc) for doc in docs if doc.get("title")]
        except (httpx.HTTPError, ValueError):
            return []

    def _parse_ol_work(self, data: dict) -> dict[str, Any]:
        """Parse a full OL work record into a work dict."""
        key = data.get("key", "")
        ol_id = extract_ol_id(key)
        return {
            "id": str(generate_uuid(ol_id)),
            "title": data.get("title", ""),
            "description": extract_text_value(data.get("description")),
            "first_published_year": extract_year(data.get("first_publish_date")),
            "open_library_work_id": ol_id,
            "subjects": data.get("subjects", []),
            "cover_ol_ids": _extract_cover_ids(data),
            "author_ol_ids": _extract_author_ol_ids(data),
        }

    def _parse_search_doc(self, doc: dict) -> dict[str, Any]:
        """Parse an OL search result doc into a work dict."""
        key = doc.get("key", "")
        ol_id = extract_ol_id(key)
        return {
            "id": str(generate_uuid(ol_id)),
            "title": doc.get("title", ""),
            "description": None,
            "first_published_year": doc.get("first_publish_year"),
            "open_library_work_id": ol_id,
            "subjects": doc.get("subject", [])[:20],
            "cover_ol_ids": [],
            "author_ol_ids": [
                extract_ol_id(k) for k in doc.get("author_key", [])
            ],
        }

    async def _upsert_work(self, work_data: dict[str, Any]) -> None:
        """Upsert a work into the database."""
        now = datetime.now(timezone.utc)
        subjects = work_data.get("subjects")
        if isinstance(subjects, list) and subjects:
            subjects = [s for s in subjects if isinstance(s, str)][:50]
        else:
            subjects = None

        cover_ol_ids = work_data.get("cover_ol_ids") or None

        await self._session.execute(
            text("""
                INSERT INTO works (id, title, description, first_published_year,
                                 open_library_work_id, subjects, cover_ol_ids,
                                 created_at, updated_at)
                VALUES (:id, :title, :description, :first_published_year,
                        :open_library_work_id, :subjects, :cover_ol_ids,
                        :created_at, :updated_at)
                ON CONFLICT (open_library_work_id) DO UPDATE SET
                    title = EXCLUDED.title,
                    description = COALESCE(EXCLUDED.description, works.description),
                    updated_at = EXCLUDED.updated_at
            """),
            {
                "id": work_data["id"],
                "title": work_data["title"],
                "description": work_data.get("description"),
                "first_published_year": work_data.get("first_published_year"),
                "open_library_work_id": work_data["open_library_work_id"],
                "subjects": subjects,
                "cover_ol_ids": cover_ol_ids,
                "created_at": now,
                "updated_at": now,
            },
        )

        # Upsert authors
        for author_ol_id in work_data.get("author_ol_ids", []):
            author_uuid = str(generate_uuid(author_ol_id))
            await self._session.execute(
                text("""
                    INSERT INTO work_authors (work_id, author_id)
                    VALUES (:work_id, :author_id)
                    ON CONFLICT (work_id, author_id) DO NOTHING
                """),
                {"work_id": work_data["id"], "author_id": author_uuid},
            )
