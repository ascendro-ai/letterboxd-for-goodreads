"""Shared helper functions for Open Library dump parsing."""

from __future__ import annotations

import gzip
import itertools
import uuid
from pathlib import Path
from typing import Any, Generator, Iterable, Iterator

import orjson

from pipeline.config import SHELF_UUID_NAMESPACE


def generate_uuid(ol_id: str) -> uuid.UUID:
    """Generate a deterministic UUID5 from an Open Library ID.

    This ensures the same OL ID always produces the same UUID,
    making imports idempotent.
    """
    return uuid.uuid5(SHELF_UUID_NAMESPACE, ol_id)


def extract_ol_id(key: str) -> str:
    """Extract the OL ID from an Open Library key path.

    Example: '/authors/OL123A' → 'OL123A'
    """
    return key.rsplit("/", 1)[-1]


def extract_text_value(field: Any) -> str | None:
    """Extract a text value from an OL field that may be a string or {type, value} dict.

    OL stores some fields (like descriptions, bios) as either:
      - A plain string: "Some description"
      - A dict: {"type": "/type/text", "value": "Some description"}
    """
    if field is None:
        return None
    if isinstance(field, str):
        return field.strip() or None
    if isinstance(field, dict):
        val = field.get("value", "")
        if isinstance(val, str):
            return val.strip() or None
    return None


def extract_year(date_str: Any) -> int | None:
    """Extract a 4-digit year from a free-form date string.

    Handles formats like: "2020", "January 1, 2020", "2020-01-15", "c. 1985".
    Returns None for unparseable dates.
    """
    if date_str is None:
        return None
    if isinstance(date_str, int):
        if 1000 <= date_str <= 9999:
            return date_str
        return None
    if not isinstance(date_str, str):
        return None
    # Find any 4-digit number that could be a year
    import re

    match = re.search(r"\b(\d{4})\b", date_str)
    if match:
        year = int(match.group(1))
        if 1000 <= year <= 2100:
            return year
    return None


def parse_tsv_json(line: str) -> dict[str, Any] | None:
    """Parse a single TSV line from an OL dump, returning the JSON data.

    OL dump format: type \\t key \\t revision \\t last_modified \\t json_data
    Returns None if parsing fails.
    """
    try:
        parts = line.split("\t", 4)
        if len(parts) < 5:
            return None
        json_data = orjson.loads(parts[4])
        return json_data
    except (orjson.JSONDecodeError, IndexError, ValueError):
        return None


def stream_tsv_lines(path: Path) -> Generator[str, None, None]:
    """Stream lines from a gzipped TSV file without loading into memory.

    Yields decoded lines one at a time.
    """
    with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
        for line in f:
            stripped = line.rstrip("\n")
            if stripped:
                yield stripped


def batched(iterable: Iterable, n: int) -> Iterator[list]:
    """Batch an iterable into lists of size n.

    The last batch may be shorter.
    """
    it = iter(iterable)
    while True:
        batch = list(itertools.islice(it, n))
        if not batch:
            break
        yield batch
