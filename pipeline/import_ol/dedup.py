"""Upsert SQL generators with conflict resolution for bulk imports."""

from __future__ import annotations


def authors_on_conflict_sql() -> str:
    """SQL ON CONFLICT clause for upserting authors."""
    return """
        INSERT INTO authors (id, name, bio, photo_url, open_library_author_id, created_at, updated_at)
        SELECT id, name, bio, photo_url, open_library_author_id, created_at, updated_at
        FROM staging_authors
        ON CONFLICT (open_library_author_id) DO UPDATE SET
            name = EXCLUDED.name,
            -- COALESCE preserves existing data when incoming value is NULL
            bio = COALESCE(EXCLUDED.bio, authors.bio),
            updated_at = NOW()
    """


def works_on_conflict_sql() -> str:
    """SQL ON CONFLICT clause for upserting works."""
    return """
        INSERT INTO works (id, title, original_title, description, first_published_year,
                          open_library_work_id, google_books_id, subjects, cover_image_url,
                          cover_ol_ids, average_rating, ratings_count, created_at, updated_at)
        SELECT id, title, original_title, description, first_published_year,
               open_library_work_id, google_books_id, subjects, cover_image_url,
               cover_ol_ids, average_rating, ratings_count, created_at, updated_at
        FROM staging_works
        ON CONFLICT (open_library_work_id) DO UPDATE SET
            title = EXCLUDED.title,
            description = COALESCE(EXCLUDED.description, works.description),
            first_published_year = COALESCE(EXCLUDED.first_published_year, works.first_published_year),
            subjects = COALESCE(EXCLUDED.subjects, works.subjects),
            cover_ol_ids = COALESCE(EXCLUDED.cover_ol_ids, works.cover_ol_ids),
            updated_at = NOW()
    """


def work_authors_on_conflict_sql() -> str:
    """SQL ON CONFLICT clause for upserting work-author relationships."""
    return """
        INSERT INTO work_authors (work_id, author_id)
        SELECT work_id, author_id
        FROM staging_work_authors
        ON CONFLICT (work_id, author_id) DO NOTHING
    """


def editions_on_conflict_sql() -> str:
    """SQL ON CONFLICT clause for upserting editions."""
    return """
        INSERT INTO editions (id, work_id, isbn_10, isbn_13, publisher, publish_date,
                             page_count, format, language, cover_image_url,
                             open_library_edition_id, created_at, updated_at)
        SELECT id, work_id, isbn_10, isbn_13, publisher, publish_date,
               page_count, format, language, cover_image_url,
               open_library_edition_id, created_at, updated_at
        FROM staging_editions
        ON CONFLICT (open_library_edition_id) DO UPDATE SET
            isbn_10 = COALESCE(EXCLUDED.isbn_10, editions.isbn_10),
            isbn_13 = COALESCE(EXCLUDED.isbn_13, editions.isbn_13),
            publisher = COALESCE(EXCLUDED.publisher, editions.publisher),
            page_count = COALESCE(EXCLUDED.page_count, editions.page_count),
            format = COALESCE(EXCLUDED.format, editions.format),
            language = COALESCE(EXCLUDED.language, editions.language),
            updated_at = NOW()
    """


def detect_isbn_duplicates_sql() -> str:
    """SQL to find works that share an ISBN (via editions), indicating potential duplicates.

    Returns pairs of (work_id_a, work_id_b, shared_isbn) for manual review.
    """
    return """
        SELECT DISTINCT e1.work_id AS work_id_a, e2.work_id AS work_id_b,
               COALESCE(e1.isbn_13, e1.isbn_10) AS shared_isbn
        FROM editions e1
        JOIN editions e2
            ON (e1.isbn_13 = e2.isbn_13 OR e1.isbn_10 = e2.isbn_10)
            AND e1.work_id < e2.work_id
        WHERE e1.isbn_13 IS NOT NULL OR e1.isbn_10 IS NOT NULL
    """
