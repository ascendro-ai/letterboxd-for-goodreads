"""Kindle clippings import service.

Parses the 'My Clippings.txt' file exported from Kindle devices, extracts
unique book titles, and matches them against the catalog.
"""

from __future__ import annotations

import re
from dataclasses import dataclass


@dataclass
class KindleClipping:
    title: str
    author: str | None
    clipping_type: str  # "Highlight", "Note", "Bookmark"
    location: str | None
    date: str | None
    content: str | None


def parse_kindle_clippings(content: str) -> list[KindleClipping]:
    """Parse Kindle 'My Clippings.txt' format.

    Format:
        Book Title (Author Name)
        - Your Highlight on page X | location X-X | Added on Date

        Highlighted text content
        ==========
    """
    clippings = []
    entries = content.split("==========")

    for entry in entries:
        entry = entry.strip()
        if not entry:
            continue

        lines = entry.split("\n")
        if len(lines) < 2:
            continue

        # Line 1: "Book Title (Author Name)" or "Book Title"
        title_line = lines[0].strip()
        # Remove BOM if present
        title_line = title_line.lstrip("\ufeff")
        author = None
        title = title_line

        author_match = re.search(r"\(([^)]+)\)\s*$", title_line)
        if author_match:
            author = author_match.group(1)
            title = title_line[: author_match.start()].strip()

        # Line 2: "- Your Highlight on page X | location X-X | Added on Date"
        meta_line = lines[1].strip() if len(lines) > 1 else ""
        clipping_type = "Highlight"
        if "Bookmark" in meta_line:
            clipping_type = "Bookmark"
        elif "Note" in meta_line:
            clipping_type = "Note"

        # Extract date from meta line
        date = None
        date_match = re.search(r"Added on (.+)$", meta_line)
        if date_match:
            date = date_match.group(1).strip()

        # Content starts after the blank line (line 3+)
        content_text = "\n".join(lines[3:]).strip() if len(lines) > 3 else None

        clippings.append(
            KindleClipping(
                title=title,
                author=author,
                clipping_type=clipping_type,
                location=meta_line,
                date=date,
                content=content_text or None,
            )
        )

    return clippings


def extract_unique_books(clippings: list[KindleClipping]) -> list[dict]:
    """Extract unique books from clippings with highlight counts."""
    unique: dict[tuple[str, str | None], dict] = {}

    for clip in clippings:
        key = (clip.title, clip.author)
        if key not in unique:
            unique[key] = {
                "title": clip.title,
                "author": clip.author,
                "highlight_count": 0,
                "note_count": 0,
                "bookmark_count": 0,
            }
        if clip.clipping_type == "Highlight":
            unique[key]["highlight_count"] += 1
        elif clip.clipping_type == "Note":
            unique[key]["note_count"] += 1
        elif clip.clipping_type == "Bookmark":
            unique[key]["bookmark_count"] += 1

    return list(unique.values())
