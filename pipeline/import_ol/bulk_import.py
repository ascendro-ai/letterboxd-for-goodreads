"""Orchestrator for bulk importing Open Library dumps.

Usage:
    python -m pipeline.import_ol.bulk_import
    python -m pipeline.import_ol.bulk_import --authors-only
    python -m pipeline.import_ol.bulk_import --skip-download --dump-dir /data/ol_dumps
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Generator

import httpx
import psycopg

from pipeline.config import (
    OL_AUTHORS_DUMP_URL,
    OL_EDITIONS_DUMP_URL,
    OL_WORKS_DUMP_URL,
    load_config,
)
from pipeline.db import sync_connection
from pipeline.import_ol.dedup import (
    authors_on_conflict_sql,
    editions_on_conflict_sql,
    work_authors_on_conflict_sql,
    works_on_conflict_sql,
)
from pipeline.import_ol.helpers import batched, generate_uuid
from pipeline.import_ol.parse_authors import stream_authors
from pipeline.import_ol.parse_editions import stream_editions
from pipeline.import_ol.parse_works import stream_works

logger = logging.getLogger(__name__)

DEFAULT_BATCH_SIZE = 10_000
LOG_EVERY_N_ROWS = 100_000


def download_dump(url: str, dest: Path) -> Path:
    """Download an OL dump file via streaming HTTP, never fully in memory."""
    logger.info("Downloading %s → %s", url, dest)
    dest.parent.mkdir(parents=True, exist_ok=True)

    with httpx.stream("GET", url, follow_redirects=True, timeout=None) as response:
        response.raise_for_status()
        with open(dest, "wb") as f:
            for chunk in response.iter_bytes(chunk_size=1024 * 1024):
                f.write(chunk)

    logger.info("Download complete: %s (%.1f GB)", dest, dest.stat().st_size / 1e9)
    return dest


# -- Staging table DDL ---------------------------------------------------------


STAGING_AUTHORS_DDL = """
    CREATE UNLOGGED TABLE IF NOT EXISTS staging_authors (
        id UUID, name TEXT, bio TEXT, photo_url TEXT,
        open_library_author_id TEXT, created_at TIMESTAMP, updated_at TIMESTAMP
    )
"""

STAGING_WORKS_DDL = """
    CREATE UNLOGGED TABLE IF NOT EXISTS staging_works (
        id UUID, title TEXT, original_title TEXT, description TEXT,
        first_published_year INTEGER, open_library_work_id TEXT,
        google_books_id TEXT, subjects TEXT[], cover_image_url TEXT,
        cover_ol_ids TEXT[], average_rating NUMERIC, ratings_count INTEGER,
        created_at TIMESTAMP, updated_at TIMESTAMP
    )
"""

STAGING_WORK_AUTHORS_DDL = """
    CREATE UNLOGGED TABLE IF NOT EXISTS staging_work_authors (
        work_id UUID, author_id UUID
    )
"""

STAGING_EDITIONS_DDL = """
    CREATE UNLOGGED TABLE IF NOT EXISTS staging_editions (
        id UUID, work_id UUID, isbn_10 TEXT, isbn_13 TEXT,
        publisher TEXT, publish_date TEXT, page_count INTEGER,
        format TEXT, language TEXT, cover_image_url TEXT,
        open_library_edition_id TEXT, created_at TIMESTAMP, updated_at TIMESTAMP
    )
"""


def _create_staging_table(conn: psycopg.Connection, ddl: str, table_name: str) -> None:
    """Create (or truncate) a staging table."""
    with conn.cursor() as cur:
        cur.execute(f"DROP TABLE IF EXISTS {table_name}")
        cur.execute(ddl)
    conn.commit()


def _copy_batch_to_staging(
    conn: psycopg.Connection,
    table_name: str,
    columns: list[str],
    rows: list[tuple],
) -> None:
    """COPY a batch of rows into a staging table using psycopg3."""
    cols = ", ".join(columns)
    with conn.cursor() as cur:
        with cur.copy(f"COPY {table_name} ({cols}) FROM STDIN") as copy:
            for row in rows:
                copy.write_row(row)
    conn.commit()


def _upsert_from_staging(conn: psycopg.Connection, upsert_sql: str, staging_table: str) -> int:
    """Run the upsert SQL from staging → target table, return row count."""
    with conn.cursor() as cur:
        cur.execute(upsert_sql)
        count = cur.rowcount
        cur.execute(f"DROP TABLE IF EXISTS {staging_table}")
    conn.commit()
    return count


# -- Import functions -----------------------------------------------------------


def import_authors(conn: psycopg.Connection, dump_path: Path, batch_size: int) -> int:
    """Import authors from OL dump into the database."""
    logger.info("Importing authors from %s", dump_path)
    now = datetime.now(timezone.utc)
    total = 0

    _create_staging_table(conn, STAGING_AUTHORS_DDL, "staging_authors")

    for batch in batched(stream_authors(dump_path), batch_size):
        rows = [
            (
                str(a["id"]),
                a["name"],
                a["bio"],
                a["photo_url"],
                a["open_library_author_id"],
                now,
                now,
            )
            for a in batch
        ]
        _copy_batch_to_staging(
            conn,
            "staging_authors",
            ["id", "name", "bio", "photo_url", "open_library_author_id", "created_at", "updated_at"],
            rows,
        )
        total += len(rows)
        if total % LOG_EVERY_N_ROWS < batch_size:
            logger.info("  Authors progress: %d rows", total)

    count = _upsert_from_staging(conn, authors_on_conflict_sql(), "staging_authors")
    logger.info("Authors import complete: %d rows processed, %d upserted", total, count)
    return total


def import_works(
    conn: psycopg.Connection, dump_path: Path, batch_size: int
) -> int:
    """Import works and work_authors from OL dump into the database."""
    logger.info("Importing works from %s", dump_path)
    now = datetime.now(timezone.utc)
    total = 0

    _create_staging_table(conn, STAGING_WORKS_DDL, "staging_works")
    _create_staging_table(conn, STAGING_WORK_AUTHORS_DDL, "staging_work_authors")

    for batch in batched(stream_works(dump_path), batch_size):
        work_rows = []
        wa_rows = []

        for w in batch:
            work_rows.append((
                str(w["id"]),
                w["title"],
                w["original_title"],
                w["description"],
                w["first_published_year"],
                w["open_library_work_id"],
                w["google_books_id"],
                w["subjects"],
                w["cover_image_url"],
                w["cover_ol_ids"],
                w["average_rating"],
                w["ratings_count"],
                now,
                now,
            ))
            for author_ol_id in w.get("author_ol_ids", []):
                wa_rows.append((str(w["id"]), str(generate_uuid(author_ol_id))))

        _copy_batch_to_staging(
            conn,
            "staging_works",
            [
                "id", "title", "original_title", "description", "first_published_year",
                "open_library_work_id", "google_books_id", "subjects", "cover_image_url",
                "cover_ol_ids", "average_rating", "ratings_count", "created_at", "updated_at",
            ],
            work_rows,
        )
        if wa_rows:
            _copy_batch_to_staging(
                conn, "staging_work_authors", ["work_id", "author_id"], wa_rows
            )

        total += len(work_rows)
        if total % LOG_EVERY_N_ROWS < batch_size:
            logger.info("  Works progress: %d rows", total)

    work_count = _upsert_from_staging(conn, works_on_conflict_sql(), "staging_works")
    wa_count = _upsert_from_staging(conn, work_authors_on_conflict_sql(), "staging_work_authors")
    logger.info(
        "Works import complete: %d rows processed, %d works upserted, %d work_authors upserted",
        total, work_count, wa_count,
    )
    return total


def import_editions(conn: psycopg.Connection, dump_path: Path, batch_size: int) -> int:
    """Import editions from OL dump into the database."""
    logger.info("Importing editions from %s", dump_path)
    now = datetime.now(timezone.utc)
    total = 0

    _create_staging_table(conn, STAGING_EDITIONS_DDL, "staging_editions")

    for batch in batched(stream_editions(dump_path), batch_size):
        rows = [
            (
                str(e["id"]),
                str(e["work_id"]),
                e["isbn_10"],
                e["isbn_13"],
                e["publisher"],
                e["publish_date"],
                e["page_count"],
                e["format"],
                e["language"],
                e["cover_image_url"],
                e["open_library_edition_id"],
                now,
                now,
            )
            for e in batch
        ]
        _copy_batch_to_staging(
            conn,
            "staging_editions",
            [
                "id", "work_id", "isbn_10", "isbn_13", "publisher", "publish_date",
                "page_count", "format", "language", "cover_image_url",
                "open_library_edition_id", "created_at", "updated_at",
            ],
            rows,
        )
        total += len(rows)
        if total % LOG_EVERY_N_ROWS < batch_size:
            logger.info("  Editions progress: %d rows", total)

    count = _upsert_from_staging(conn, editions_on_conflict_sql(), "staging_editions")
    logger.info("Editions import complete: %d rows processed, %d upserted", total, count)
    return total


# -- CLI -----------------------------------------------------------------------


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Bulk import Open Library dumps into Shelf DB")
    parser.add_argument("--authors-only", action="store_true", help="Import only authors")
    parser.add_argument("--works-only", action="store_true", help="Import only works")
    parser.add_argument("--editions-only", action="store_true", help="Import only editions")
    parser.add_argument("--skip-download", action="store_true", help="Use pre-downloaded dumps")
    parser.add_argument(
        "--dump-dir", type=Path, default=Path("/tmp/ol_dumps"),
        help="Directory for dump files (default: /tmp/ol_dumps)",
    )
    parser.add_argument(
        "--batch-size", type=int, default=DEFAULT_BATCH_SIZE,
        help=f"Rows per COPY batch (default: {DEFAULT_BATCH_SIZE})",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    args = parse_args(argv)
    config = load_config()

    # Determine which entity types to import
    import_all = not (args.authors_only or args.works_only or args.editions_only)
    do_authors = import_all or args.authors_only
    do_works = import_all or args.works_only
    do_editions = import_all or args.editions_only

    dump_dir = args.dump_dir
    dump_dir.mkdir(parents=True, exist_ok=True)

    # Download dumps if needed
    if not args.skip_download:
        if do_authors:
            download_dump(OL_AUTHORS_DUMP_URL, dump_dir / "ol_dump_authors_latest.txt.gz")
        if do_works:
            download_dump(OL_WORKS_DUMP_URL, dump_dir / "ol_dump_works_latest.txt.gz")
        if do_editions:
            download_dump(OL_EDITIONS_DUMP_URL, dump_dir / "ol_dump_editions_latest.txt.gz")

    start = time.monotonic()

    with sync_connection(config) as conn:
        # Import order: authors → works (+ work_authors) → editions
        if do_authors:
            import_authors(conn, dump_dir / "ol_dump_authors_latest.txt.gz", args.batch_size)
        if do_works:
            import_works(conn, dump_dir / "ol_dump_works_latest.txt.gz", args.batch_size)
        if do_editions:
            import_editions(conn, dump_dir / "ol_dump_editions_latest.txt.gz", args.batch_size)

    elapsed = time.monotonic() - start
    logger.info("Bulk import completed in %.1f seconds", elapsed)


if __name__ == "__main__":
    main()
