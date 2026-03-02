# Shelf — Letterboxd for Books

A Letterboxd-style iOS app for tracking books. Working title: **Shelf**.

## Architecture Overview

```
┌─────────────┐     ┌──────────────────────────────────┐     ┌─────────────┐
│   iOS App   │────▶│  FastAPI Backend (Railway)        │────▶│  Supabase   │
│  (SwiftUI)  │◀────│  /api/v1/*                        │◀────│  Postgres   │
└─────────────┘     └──────────────────────────────────┘     └──────┬──────┘
       │                        │                                   │
       │                        ▼                                   │
       │              ┌──────────────────┐                          │
       │              │  Supabase Auth   │                          │
       │              │  (JWT provider)  │                          │
       │              └──────────────────┘                          │
       │                                                            │
       ▼                                                            ▼
┌─────────────┐     ┌──────────────────────────────────┐     ┌─────────────┐
│  RevenueCat │     │  Data Pipeline (Railway cron)    │     │ Cloudflare  │
│  (payments) │     │  - Bulk OL import                │     │  R2 + CDN   │
└─────────────┘     │  - Nightly sync                  │     │  (covers)   │
                    │  - Cover processing              │     └─────────────┘
                    │  - Taste match computation        │
                    └──────────────────────────────────┘
```

### Data Flow

1. **Book catalog** originates from Open Library bulk dumps (~40M works). The pipeline parses TSV+JSON dumps, generates deterministic UUIDs (UUID5 from OL IDs for idempotent re-runs), and bulk-inserts via staging tables.
2. **Nightly sync** polls OL's Recent Changes API to pick up new/updated works since the last run. Also recomputes taste match scores between users.
3. **Cover images** are fetched from OL (primary) or Google Books (fallback), converted to WebP, resized to 4 variants (thumb/card/detail/hero), and uploaded to Cloudflare R2.
4. **Users** authenticate via Supabase Auth (Apple, Google, or email). The backend validates JWTs — it never stores passwords.
5. **iOS app** talks exclusively to the FastAPI backend. Offline mutations are queued locally (SwiftData) and replayed on reconnect.

### Key Architectural Decisions

| Decision | Rationale |
|----------|-----------|
| **Work-level logging** (not edition) | Like Letterboxd logs films not Blu-rays. Simpler UX, avoids "which edition did you read?" friction. |
| **Fan-out on read** (feed) | Simple JOIN query. Acceptable at our scale (<100K users). Switch to fan-out on write if feed latency exceeds 200ms. |
| **Half-star ratings** (0.5–5.0) | Stored as Numeric(2,1). More expressive than 5-star, less confusing than 10-point. Matches Letterboxd. |
| **Cursor-keyset pagination** | (created_at, id) compound cursor avoids offset drift when new rows are inserted. Clients treat it as an opaque base64 string. |
| **Deterministic UUIDs** (pipeline) | UUID5 from OL IDs means re-running the import produces identical keys. No duplicates, safe upserts. |
| **Separate pipeline models** | Pipeline runs independently from the backend — no shared imports. Models are intentionally duplicated (TODO: unify via shared package). |
| **UNLOGGED staging tables** (bulk import) | Skips WAL for ~2x write speed. Acceptable because staging data is ephemeral — if the DB crashes mid-import, we re-run. |

## Monorepo Structure

```
/
├── backend/              # Python FastAPI REST API
│   ├── api/              # Route handlers, schemas, middleware
│   │   ├── routes/       # Endpoint handlers grouped by domain
│   │   ├── schemas/      # Pydantic request/response models
│   │   ├── config.py     # Settings from env vars (cached at startup)
│   │   ├── database.py   # Async engine + session factory
│   │   ├── deps.py       # FastAPI dependency injection (auth, DB session)
│   │   ├── errors.py     # Standardized error responses
│   │   ├── pagination.py # Cursor-keyset pagination helpers
│   │   └── main.py       # App factory, middleware, CORS
│   ├── models/           # SQLAlchemy 2.0 ORM models
│   ├── migrations/       # Alembic (async, targets Postgres)
│   ├── services/         # Business logic layer (no HTTP concerns)
│   └── tests/            # Pytest + pytest-asyncio (SQLite in-memory)
├── pipeline/             # Data pipeline (runs on Railway cron)
│   ├── import_ol/        # Bulk Open Library TSV+JSON import
│   ├── cover_processing/ # Fetch → WebP convert → resize → R2 upload
│   ├── sync/             # Nightly OL sync + taste match computation
│   └── tests/            # Pipeline-specific tests
├── ios/                  # Native iOS app (Swift/SwiftUI, iOS 17+)
│   ├── Shelf/            # Main app target
│   │   ├── Models/       # Codable data models matching API responses
│   │   ├── Services/     # API client, auth, sync, offline store
│   │   ├── ViewModels/   # @Observable view models
│   │   ├── Views/        # SwiftUI views grouped by feature
│   │   └── Components/   # Reusable UI components
│   ├── ShelfShareExtension/  # Share extension (ISBN from URLs)
│   └── ShelfTests/       # XCTest unit tests
├── infra/                # Docker, Railway, GitHub Actions (TODO)
└── docs/                 # API contract, architecture notes
```

## Tech Stack

| Layer | Tech | Notes |
|-------|------|-------|
| iOS | Swift, SwiftUI | iOS 17+, SwiftData for offline cache |
| Backend | Python 3.12+, FastAPI | Async everywhere, SQLAlchemy 2.0 |
| Database | Supabase Postgres | pg_trgm for fuzzy search, GIN indexes |
| Auth | Supabase Auth | Apple, Google, email+password. Backend validates JWT. |
| Storage | Cloudflare R2 + CDN | Cover images in 4 sizes (WebP) |
| Hosting | Railway | Backend + pipeline cron jobs |
| Payments | RevenueCat + StoreKit | Premium unlocks: no ads, unlimited shelves |
| Ads | Google AdMob | 1 ad per 8 content items, premium exempt |
| Analytics | PostHog, Sentry | 20% analytics sampling, 10% performance |

## Business Rules

These are non-obvious rules enforced in code that future developers should know:

- **Review required for ratings**: New ratings must include review text. Encourages thoughtful ratings. Imported books are exempt (already rated elsewhere).
- **Block cascades**: Blocking a user auto-unfollows in both directions and clears any mutes. Ensures full separation.
- **Activity feed filtering**: Only "started reading" and "finished reading" create feed entries. "Want to read" and "did not finish" are silent — they clutter feeds without being interesting.
- **Shelf limits**: Free tier allows 20 custom shelves. Premium unlocks unlimited. Standard status shelves (read, reading, want-to-read) are status fields, not shelves.
- **Soft delete**: Users are soft-deleted (deleted_at timestamp). Reviews and activity persist but are anonymized. Matches GDPR requirements.
- **Import matching waterfall**: ISBN-13 → ISBN-10 → exact title match → fuzzy title (ILIKE). Order matters — ISBN is precise, fuzzy is a last resort.
- **Taste match threshold**: Only computed when two users share 5+ rated books. Fewer than that produces unreliable scores.

## Conventions

- **Python**: `ruff` for linting/formatting. Type hints everywhere. Async endpoints.
- **Swift**: SwiftUI-first. @Observable (not @Published). Follow Apple HIG.
- **Database**: All table/column names snake_case. UUIDs for all PKs. Alembic for all schema changes.
- **API**: RESTful. All endpoints under `/api/v1/`. JSON bodies. Standard HTTP status codes.
- **Tests**: Written alongside implementation. Pytest (Python), XCTest (iOS). SQLite in-memory for fast Python tests.
- **Commits**: Conventional commits (`feat:`, `fix:`, `chore:`, `docs:`).
- **Documentation**: Module-level docstrings on all files. Inline comments only for "why" (business rules, non-obvious decisions, magic numbers). No comment-the-obvious.

## Running Locally

### Backend
```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
alembic upgrade head
uvicorn api.main:app --reload --port 8000
```

### Pipeline
```bash
cd pipeline
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
# Bulk import (one-time):
python -m import_ol.bulk_import --authors authors.tsv.gz --works works.tsv.gz --editions editions.tsv.gz
# Nightly sync:
python -m sync.nightly_sync
```

### iOS
Open `ios/Shelf/Shelf.xcodeproj` in Xcode. Requires iOS 17+ simulator or device.

### Tests
```bash
# Backend (from backend/):
pytest tests/ -v

# Pipeline (from pipeline/):
pytest tests/ -v
```

## Environment Variables

### Backend
```
DATABASE_URL=postgresql+asyncpg://...
SUPABASE_URL=https://...
SUPABASE_SERVICE_KEY=...
SUPABASE_JWT_SECRET=...
SENTRY_DSN=...
CLOUDFLARE_R2_ENDPOINT=...
CLOUDFLARE_R2_ACCESS_KEY=...
CLOUDFLARE_R2_SECRET_KEY=...
BOOKSHOP_AFFILIATE_ID=...
```

### Pipeline
```
DATABASE_URL=postgresql+psycopg://...    # Note: psycopg (sync) not asyncpg — COPY needs sync driver
OL_AUTHORS_DUMP_URL=...
OL_WORKS_DUMP_URL=...
OL_EDITIONS_DUMP_URL=...
CLOUDFLARE_R2_ENDPOINT=...
CLOUDFLARE_R2_ACCESS_KEY=...
CLOUDFLARE_R2_SECRET_KEY=...
CLOUDFLARE_R2_BUCKET=...
CLOUDFLARE_CDN_BASE_URL=...
GOOGLE_BOOKS_API_KEY=...                 # Optional, for cover fallback (1000 req/day free tier)
```
