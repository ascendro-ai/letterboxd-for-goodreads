"""Kobo e-reader import service.

Parses the KoboReader.sqlite database export to extract reading data.
"""

from __future__ import annotations

import sqlite3
import tempfile
from dataclasses import dataclass


@dataclass
class KoboBook:
    title: str
    author: str | None
    status: str  # "read" or "reading"
    percent_read: float | None


def parse_kobo_db(file_content: bytes) -> list[KoboBook]:
    """Parse Kobo's KoboReader.sqlite export.

    Relevant tables:
      - content: BookID, Title, Attribution (author), ReadStatus, ___PercentRead
    """
    books = []

    with tempfile.NamedTemporaryFile(suffix=".sqlite", delete=True) as tmp:
        tmp.write(file_content)
        tmp.flush()

        conn = sqlite3.connect(tmp.name)
        try:
            cursor = conn.cursor()
            cursor.execute(
                """
                SELECT Title, Attribution, ReadStatus, ___PercentRead
                FROM content
                WHERE BookTitle IS NOT NULL
                AND ContentType = 6
                ORDER BY ___PercentRead DESC
                """
            )

            for title, author, _read_status, percent in cursor.fetchall():
                if not title:
                    continue
                status = "read" if percent and percent >= 99 else "reading"
                books.append(
                    KoboBook(
                        title=title,
                        author=author,
                        status=status,
                        percent_read=percent,
                    )
                )
        finally:
            conn.close()

    return books
