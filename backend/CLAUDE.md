# Backend — Scope & Instructions

## Ownership

This directory contains the FastAPI backend. Two worktree instances work here:

- **backend/database** branch owns: `models/`, `migrations/`
- **backend/api-core** branch owns: `api/`, `services/`, `tests/`

Do NOT modify files outside your owned directories.

## Architecture

```
backend/
├── api/
│   ├── __init__.py
│   ├── main.py              # FastAPI app factory, middleware, CORS
│   ├── deps.py              # Dependency injection (db session, current user)
│   ├── routes/
│   │   ├── auth.py          # Login, signup, token refresh
│   │   ├── books.py         # Search, detail, barcode lookup
│   │   ├── users.py         # Profile, follow/unfollow, block/mute
│   │   ├── user_books.py    # Log, rate, review, update status
│   │   ├── shelves.py       # CRUD shelves, add/remove books
│   │   ├── feed.py          # Activity feed, notifications
│   │   └── import_.py       # Trigger Goodreads/StoryGraph import
│   └── schemas/             # Pydantic request/response models
├── models/
│   ├── __init__.py
│   ├── base.py              # SQLAlchemy declarative base, common mixins
│   ├── work.py              # Work, Edition, Author models
│   ├── user.py              # User model
│   ├── user_book.py         # UserBook, Shelf, ShelfBook models
│   ├── social.py            # Follow, Block, Mute, Activity models
│   └── taste_match.py       # TasteMatch model
├── migrations/              # Alembic migrations
│   ├── alembic.ini
│   ├── env.py
│   └── versions/
├── services/
│   ├── book_service.py      # Search, lookup, barcode resolution
│   ├── import_service.py    # CSV parsing, matching waterfall
│   ├── feed_service.py      # Activity feed queries
│   ├── taste_service.py     # Taste match computation
│   └── moderation_service.py
├── tests/
│   ├── conftest.py          # Fixtures, test DB setup
│   ├── test_books.py
│   ├── test_user_books.py
│   ├── test_import.py
│   └── test_feed.py
├── requirements.txt
└── pyproject.toml
```

## Key Design Decisions

- All endpoints async (`async def`)
- SQLAlchemy 2.0 style (mapped_column, not Column)
- Supabase Auth handles authentication — backend validates JWT from `Authorization: Bearer <token>` header
- Database session via FastAPI dependency injection
- Parameterized queries only (SQLAlchemy handles this)
- All IDs are UUIDs
- Ratings stored as `Numeric(2,1)` — range 0.5 to 5.0, half-star increments
- Feed: fan-out on read (simple JOIN, no denormalization yet)

## Environment Variables

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

## Running Locally

```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
alembic upgrade head
uvicorn api.main:app --reload --port 8000
```

## Testing

```bash
pytest tests/ -v
```
