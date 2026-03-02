"""Parse Open Library editions dump into edition records."""

from __future__ import annotations

from pathlib import Path
from typing import Any, Generator

from pipeline.import_ol.helpers import (
    extract_ol_id,
    generate_uuid,
    parse_tsv_json,
    stream_tsv_lines,
)

# Normalize OL format strings to our standard set
FORMAT_MAP: dict[str, str] = {
    "hardcover": "hardcover",
    "hardback": "hardcover",
    "hardbound": "hardcover",
    "paperback": "paperback",
    "softcover": "paperback",
    "mass market paperback": "paperback",
    "mass market": "paperback",
    "trade paperback": "paperback",
    "ebook": "ebook",
    "e-book": "ebook",
    "electronic resource": "ebook",
    "kindle edition": "ebook",
    "audiobook": "audiobook",
    "audio cd": "audiobook",
    "audio cassette": "audiobook",
    "mp3 cd": "audiobook",
}


def _normalize_format(raw: Any) -> str | None:
    """Normalize a physical_format string to one of: hardcover, paperback, ebook, audiobook."""
    if not raw or not isinstance(raw, str):
        return None
    return FORMAT_MAP.get(raw.strip().lower())


def _extract_isbn(data: dict[str, Any], key: str) -> str | None:
    """Extract first ISBN from an OL isbn_10 or isbn_13 array."""
    values = data.get(key, [])
    if isinstance(values, list) and values:
        isbn = values[0]
        if isinstance(isbn, str) and isbn.strip():
            return isbn.strip()
    return None


def _extract_language(data: dict[str, Any]) -> str | None:
    """Extract language code from OL languages array.

    OL stores languages as [{"key": "/languages/eng"}].
    """
    langs = data.get("languages", [])
    if not isinstance(langs, list) or not langs:
        return None
    first = langs[0]
    if isinstance(first, dict):
        key = first.get("key", "")
        return extract_ol_id(key) if key else None
    return None


def _extract_page_count(data: dict[str, Any]) -> int | None:
    """Extract page count, handling various OL formats."""
    pages = data.get("number_of_pages")
    if isinstance(pages, int) and pages > 0:
        return pages
    # Sometimes stored as "number_of_pages_median" or as string
    pages_str = data.get("pagination", "")
    if isinstance(pages_str, str):
        import re

        match = re.search(r"(\d+)", pages_str)
        if match:
            val = int(match.group(1))
            if val > 0:
                return val
    return None


def parse_edition(data: dict[str, Any]) -> dict[str, Any] | None:
    """Parse a single OL edition JSON record into a flat dict.

    Returns None if the edition is an orphan (no work reference).
    """
    # Editions must reference a work
    works = data.get("works", [])
    if not isinstance(works, list) or not works:
        return None
    work_ref = works[0]
    if not isinstance(work_ref, dict):
        return None
    work_key = work_ref.get("key", "")
    if not work_key:
        return None

    work_ol_id = extract_ol_id(work_key)

    key = data.get("key", "")
    ol_id = extract_ol_id(key)

    publishers = data.get("publishers", [])
    publisher = publishers[0] if isinstance(publishers, list) and publishers else None
    if isinstance(publisher, str):
        publisher = publisher.strip() or None

    return {
        "id": generate_uuid(ol_id),
        "work_id": generate_uuid(work_ol_id),
        "isbn_10": _extract_isbn(data, "isbn_10"),
        "isbn_13": _extract_isbn(data, "isbn_13"),
        "publisher": publisher,
        "publish_date": data.get("publish_date"),
        "page_count": _extract_page_count(data),
        "format": _normalize_format(data.get("physical_format")),
        "language": _extract_language(data),
        "cover_image_url": None,
        "open_library_edition_id": ol_id,
        "work_ol_id": work_ol_id,
    }


def stream_editions(dump_path: Path) -> Generator[dict[str, Any], None, None]:
    """Stream-parse the OL editions dump, yielding parsed edition dicts.

    Skips orphan editions (no work reference) and records that fail to parse.
    """
    for line in stream_tsv_lines(dump_path):
        data = parse_tsv_json(line)
        if data is None:
            continue
        edition = parse_edition(data)
        if edition is not None:
            yield edition
