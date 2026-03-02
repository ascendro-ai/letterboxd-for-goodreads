"""Parse Open Library works dump into work records."""

from __future__ import annotations

from pathlib import Path
from typing import Any, Generator

from pipeline.import_ol.helpers import (
    extract_ol_id,
    extract_text_value,
    extract_year,
    generate_uuid,
    parse_tsv_json,
    stream_tsv_lines,
)


def _extract_author_ol_ids(data: dict[str, Any]) -> list[str]:
    """Extract author OL IDs from various OL `authors` array formats.

    OL stores authors in works in several formats:
      - [{"author": {"key": "/authors/OL123A"}}]
      - [{"author": "/authors/OL123A"}]
      - [{"key": "/authors/OL123A"}]
    """
    authors_raw = data.get("authors", [])
    if not isinstance(authors_raw, list):
        return []

    ids = []
    for entry in authors_raw:
        if not isinstance(entry, dict):
            continue
        # Format: {"author": {"key": "/authors/OL123A"}} (most common)
        author_field = entry.get("author")
        if isinstance(author_field, dict):
            key = author_field.get("key", "")
            if key:
                ids.append(extract_ol_id(key))
                continue
        # Format: {"author": "/authors/OL123A"}
        if isinstance(author_field, str) and author_field.startswith("/authors/"):
            ids.append(extract_ol_id(author_field))
            continue
        # Format: {"key": "/authors/OL123A"}
        key = entry.get("key", "")
        if isinstance(key, str) and key.startswith("/authors/"):
            ids.append(extract_ol_id(key))
    return ids


def _extract_cover_ids(data: dict[str, Any]) -> list[str]:
    """Extract valid cover IDs from the covers array.

    Filters out negative IDs (which indicate deleted covers in OL).
    """
    covers = data.get("covers", [])
    if not isinstance(covers, list):
        return []
    return [str(c) for c in covers if isinstance(c, int) and c > 0]


def parse_work(data: dict[str, Any]) -> dict[str, Any] | None:
    """Parse a single OL work JSON record into a flat dict.

    Returns None if the record has no title (required field).
    """
    title = data.get("title", "").strip()
    if not title:
        return None

    key = data.get("key", "")
    ol_id = extract_ol_id(key)

    subjects_raw = data.get("subjects", [])
    subjects = (
        [s.strip() for s in subjects_raw if isinstance(s, str) and s.strip()]
        if isinstance(subjects_raw, list)
        else []
    )

    return {
        "id": generate_uuid(ol_id),
        "title": title,
        "original_title": None,
        "description": extract_text_value(data.get("description")),
        "first_published_year": extract_year(data.get("first_publish_date")),
        "open_library_work_id": ol_id,
        "google_books_id": None,
        "subjects": subjects or None,
        "cover_image_url": None,
        "cover_ol_ids": _extract_cover_ids(data) or None,
        "average_rating": None,
        "ratings_count": 0,
        "author_ol_ids": _extract_author_ol_ids(data),
    }


def stream_works(dump_path: Path) -> Generator[dict[str, Any], None, None]:
    """Stream-parse the OL works dump, yielding parsed work dicts.

    Skips records with no title or that fail to parse.
    """
    for line in stream_tsv_lines(dump_path):
        data = parse_tsv_json(line)
        if data is None:
            continue
        work = parse_work(data)
        if work is not None:
            yield work
