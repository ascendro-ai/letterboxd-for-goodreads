# Data Pipeline — Scope & Instructions

## Ownership

The **backend/import-pipeline** branch owns everything in this directory.
Do NOT modify anything in `backend/api/`, `backend/services/`, or `ios/`.

You MAY read (but not modify) `backend/models/` — use the same SQLAlchemy models for DB writes.

## Architecture

```
pipeline/
├── import_ol/
│   ├── bulk_import.py         # Full Open Library bulk import (~40GB, 30M+ works)
│   ├── parse_works.py         # Parse OL works dump → Work model
│   ├── parse_editions.py      # Parse OL editions dump → Edition model
│   ├── parse_authors.py       # Parse OL authors dump → Author model
│   └── dedup.py               # Deduplication logic (OL ID, ISBN, fuzzy title)
├── cover_processing/
│   ├── fetch_covers.py        # Fetch covers: Open Library → Google Books fallback
│   ├── resize.py              # Generate variants: 150px, 300px, 600px, 1200px
│   ├── upload_r2.py           # Upload to Cloudflare R2
│   └── format.py              # Convert to WebP with JPEG fallback
├── sync/
│   ├── nightly_sync.py        # Open Library recent changes API → update local DB
│   ├── taste_match_job.py     # Nightly recompute taste_matches table
│   └── live_fallback.py       # On-demand API call for books not yet synced
├── tests/
│   ├── test_bulk_import.py
│   ├── test_cover_processing.py
│   ├── test_nightly_sync.py
│   └── fixtures/              # Sample OL dump excerpts for testing
├── requirements.txt
└── pyproject.toml
```

## Key Design Decisions

- Open Library bulk dumps are ~40GB compressed. Download as TSV, stream-parse, batch INSERT.
- Use COPY for bulk inserts (psycopg2 copy_from or asyncpg copy_to_table) for performance.
- Cover pipeline runs as a background job — don't block import on cover fetching.
- Cover variants: thumbnail (150px), card (300px), detail (600px), hero (1200px). All WebP.
- Nightly sync uses OL Recent Changes API (`/recentchanges?limit=1000&offset=0`).
- Taste match job: only compute for user pairs with 5+ shared rated books.
- All jobs should be idempotent (safe to re-run).

## Open Library Data

- Works dump: `https://openlibrary.org/data/ol_dump_works_latest.txt.gz`
- Editions dump: `https://openlibrary.org/data/ol_dump_editions_latest.txt.gz`
- Authors dump: `https://openlibrary.org/data/ol_dump_authors_latest.txt.gz`
- Format: TSV with columns: type, key, revision, last_modified, json_data
- The json_data column contains the full record as JSON.

## Environment Variables

```
DATABASE_URL=postgresql+asyncpg://...
CLOUDFLARE_R2_ENDPOINT=...
CLOUDFLARE_R2_ACCESS_KEY=...
CLOUDFLARE_R2_SECRET_KEY=...
CLOUDFLARE_R2_BUCKET=shelf-covers
GOOGLE_BOOKS_API_KEY=...
```

## Running

```bash
cd pipeline
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt

# Full bulk import (one-time, takes hours)
python -m import_ol.bulk_import

# Nightly sync (run via Railway cron)
python -m sync.nightly_sync

# Cover processing (background job)
python -m cover_processing.fetch_covers
```

## Testing

```bash
pytest tests/ -v
```
