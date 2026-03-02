"""Parse Open Library authors dump into author records."""

from __future__ import annotations

from pathlib import Path
from typing import Any, Generator

from pipeline.import_ol.helpers import (
    extract_ol_id,
    extract_text_value,
    generate_uuid,
    parse_tsv_json,
    stream_tsv_lines,
)


def parse_author(data: dict[str, Any]) -> dict[str, Any] | None:
    """Parse a single OL author JSON record into a flat dict.

    Returns None if the record has no name (required field).
    """
    name = data.get("name", "").strip()
    if not name:
        return None

    key = data.get("key", "")
    ol_id = extract_ol_id(key)

    return {
        "id": generate_uuid(ol_id),
        "name": name,
        "bio": extract_text_value(data.get("bio")),
        "photo_url": None,
        "open_library_author_id": ol_id,
    }


def stream_authors(dump_path: Path) -> Generator[dict[str, Any], None, None]:
    """Stream-parse the OL authors dump, yielding parsed author dicts.

    Skips records with no name or that fail to parse.
    """
    for line in stream_tsv_lines(dump_path):
        data = parse_tsv_json(line)
        if data is None:
            continue
        author = parse_author(data)
        if author is not None:
            yield author
