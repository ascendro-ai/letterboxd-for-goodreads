"""Seed the local database with dev data.

Inserts 2 users, 3 authors, 5 works, and 5 editions directly via asyncpg.
All INSERTs use ON CONFLICT DO NOTHING so this script is idempotent.

Usage:
    python scripts/seed.py
"""

import asyncio
import os
import sys

import asyncpg
from dotenv import load_dotenv

# Load .env from backend/ for DATABASE_URL
load_dotenv(os.path.join(os.path.dirname(__file__), "..", "backend", ".env"))

# asyncpg wants a plain postgres:// URL, not postgresql+asyncpg://
DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql+asyncpg://shelf:shelf@localhost:5432/shelf")
DATABASE_URL = DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://")

# Fixed UUIDs for stable dev auth tokens
USER_1 = "00000000-0000-0000-0000-000000000001"
USER_2 = "00000000-0000-0000-0000-000000000002"

AUTHOR_LEGUIN = "aaaaaaaa-0000-0000-0000-000000000001"
AUTHOR_BUTLER = "aaaaaaaa-0000-0000-0000-000000000002"
AUTHOR_CHIANG = "aaaaaaaa-0000-0000-0000-000000000003"

WORK_1 = "bbbbbbbb-0000-0000-0000-000000000001"
WORK_2 = "bbbbbbbb-0000-0000-0000-000000000002"
WORK_3 = "bbbbbbbb-0000-0000-0000-000000000003"
WORK_4 = "bbbbbbbb-0000-0000-0000-000000000004"
WORK_5 = "bbbbbbbb-0000-0000-0000-000000000005"

EDITION_1 = "cccccccc-0000-0000-0000-000000000001"
EDITION_2 = "cccccccc-0000-0000-0000-000000000002"
EDITION_3 = "cccccccc-0000-0000-0000-000000000003"
EDITION_4 = "cccccccc-0000-0000-0000-000000000004"
EDITION_5 = "cccccccc-0000-0000-0000-000000000005"


async def seed():
    conn = await asyncpg.connect(DATABASE_URL)
    try:
        # --- Users ---
        await conn.execute("""
            INSERT INTO users (id, username, display_name, is_premium, is_deleted)
            VALUES ($1, $2, $3, $4, $5)
            ON CONFLICT DO NOTHING
        """, USER_1, "devuser", "Dev User", False, False)

        await conn.execute("""
            INSERT INTO users (id, username, display_name, is_premium, is_deleted)
            VALUES ($1, $2, $3, $4, $5)
            ON CONFLICT DO NOTHING
        """, USER_2, "devuser2", "Dev User 2", True, False)

        # --- Authors ---
        await conn.execute("""
            INSERT INTO authors (id, name, bio, open_library_author_id)
            VALUES ($1, $2, $3, $4)
            ON CONFLICT DO NOTHING
        """, AUTHOR_LEGUIN, "Ursula K. Le Guin",
            "American author of novels, children's books, and short stories, mainly in the genres of fantasy and science fiction.",
            "OL26320A")

        await conn.execute("""
            INSERT INTO authors (id, name, bio, open_library_author_id)
            VALUES ($1, $2, $3, $4)
            ON CONFLICT DO NOTHING
        """, AUTHOR_BUTLER, "Octavia E. Butler",
            "American science fiction author known for incorporating science into her stories.",
            "OL22735A")

        await conn.execute("""
            INSERT INTO authors (id, name, bio, open_library_author_id)
            VALUES ($1, $2, $3, $4)
            ON CONFLICT DO NOTHING
        """, AUTHOR_CHIANG, "Ted Chiang",
            "American speculative fiction writer.",
            "OL1474579A")

        # --- Works ---
        works = [
            (WORK_1, "A Wizard of Earthsea", "A young boy discovers he has magical powers and is sent to a school for wizards.", 1968, "OL59852W"),
            (WORK_2, "The Left Hand of Darkness", "An envoy from Earth is sent to a planet where people have no fixed gender.", 1969, "OL59851W"),
            (WORK_3, "Kindred", "A modern Black woman is pulled back in time to the antebellum South.", 1979, "OL15833167W"),
            (WORK_4, "Parable of the Sower", "In a near-future dystopia, a young woman with hyper-empathy syndrome leads a group to safety.", 1993, "OL15833168W"),
            (WORK_5, "Stories of Your Life and Others", "A collection of speculative fiction short stories.", 2002, "OL3350010W"),
        ]
        for work_id, title, desc, year, ol_id in works:
            await conn.execute("""
                INSERT INTO works (id, title, description, first_published_year, open_library_work_id, ratings_count)
                VALUES ($1, $2, $3, $4, $5, 0)
                ON CONFLICT DO NOTHING
            """, work_id, title, desc, year, ol_id)

        # --- Work-Author associations ---
        associations = [
            (WORK_1, AUTHOR_LEGUIN),
            (WORK_2, AUTHOR_LEGUIN),
            (WORK_3, AUTHOR_BUTLER),
            (WORK_4, AUTHOR_BUTLER),
            (WORK_5, AUTHOR_CHIANG),
        ]
        for work_id, author_id in associations:
            await conn.execute("""
                INSERT INTO work_authors (work_id, author_id)
                VALUES ($1, $2)
                ON CONFLICT DO NOTHING
            """, work_id, author_id)

        # --- Editions (with ISBNs for barcode lookup testing) ---
        editions = [
            (EDITION_1, WORK_1, "9780547722023", "0547722028", "Clarion Books", "2012-09-11", 326),
            (EDITION_2, WORK_2, "9780441007318", "0441007317", "Ace Books", "2000-07-01", 304),
            (EDITION_3, WORK_3, "9780807083697", "0807083690", "Beacon Press", "2004-02-01", 264),
            (EDITION_4, WORK_4, "9781538732182", "1538732181", "Grand Central", "2019-11-19", 345),
            (EDITION_5, WORK_5, "9781101972120", "1101972122", "Vintage", "2016-05-31", 304),
        ]
        for ed_id, work_id, isbn13, isbn10, publisher, pub_date, pages in editions:
            await conn.execute("""
                INSERT INTO editions (id, work_id, isbn_13, isbn_10, publisher, publish_date, page_count)
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                ON CONFLICT DO NOTHING
            """, ed_id, work_id, isbn13, isbn10, publisher, pub_date, pages)

        print("Seeded successfully!")
        print()
        print("Test with:")
        print(f'  curl -H "Authorization: Bearer dev-user-{USER_1}" http://localhost:8000/api/v1/me')

    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(seed())
