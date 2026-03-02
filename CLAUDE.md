# Shelf — Letterboxd for Books

## What This Is

A Letterboxd-style iOS app for tracking books. Working title: **Shelf**.
See `technical-decisions-final.md` for the full spec.

## Monorepo Structure

```
/
├── backend/          # Python FastAPI REST API
│   ├── api/          # Route handlers (endpoints)
│   ├── models/       # SQLAlchemy ORM models
│   ├── migrations/   # Alembic database migrations
│   ├── services/     # Business logic layer
│   └── tests/        # Pytest unit + integration tests
├── ios/              # Native iOS app (Swift/SwiftUI)
│   └── Shelf/        # Xcode project
├── pipeline/         # Data pipeline (Open Library import, covers, sync)
│   ├── import_ol/    # Bulk Open Library import scripts
│   ├── cover_processing/  # Cover fetch + R2 upload + resizing
│   ├── sync/         # Nightly sync via OL recent changes API
│   └── tests/        # Pipeline-specific tests
├── infra/            # Infrastructure config (Docker, Railway, GitHub Actions)
└── docs/             # Shared docs (API contract, architecture)
```

## Git Worktree Strategy

This project is designed for parallel development using git worktrees.
Each worktree gets its own branch and works on an independent slice.

### Setup Commands

```bash
# From the main repo root:

# Instance 1 — Database models & migrations
git worktree add ../shelf-database -b backend/database

# Instance 2 — Backend API routes & services
git worktree add ../shelf-backend -b backend/api-core

# Instance 3 — iOS app
git worktree add ../shelf-ios -b ios/core

# Instance 4 — Data pipeline (Open Library import + covers)
git worktree add ../shelf-pipeline -b backend/import-pipeline
```

### Merge Order

1. **backend/database** merges first (models are the foundation)
2. **backend/api-core** and **backend/import-pipeline** rebase onto main after database merges
3. **ios/core** is independent — merge anytime

### Conflict Prevention Rules

- Each instance ONLY modifies files within its owned directories
- Shared dependencies (requirements.txt, Package.swift) — the instance that needs a new dep adds it, conflicts resolved at merge
- If you need something from another instance's scope, stub it and leave a `# TODO: provided by [other-instance]` comment

## Tech Stack Quick Reference

| Layer | Tech |
|-------|------|
| iOS | Swift, SwiftUI, minimum iOS 17+ |
| Backend | Python 3.12+, FastAPI, SQLAlchemy, Alembic |
| Database | Supabase Postgres (pg_trgm, tsvector) |
| Auth | Supabase Auth (Apple, Google, email+password) |
| Storage | Cloudflare R2 + CDN (cover images) |
| Hosting | Railway (backend + cron jobs) |
| Payments | RevenueCat + StoreKit |
| Ads | Google AdMob |
| Analytics | PostHog, Sentry |

## Conventions

- **Python**: Use `ruff` for linting/formatting. Type hints everywhere. Async endpoints.
- **Swift**: SwiftUI-first, UIKit only where noted in spec. Follow Apple HIG.
- **Database**: All table/column names snake_case. UUIDs for all primary keys. Alembic for all schema changes.
- **API**: RESTful. Endpoints namespaced under `/api/v1/`. JSON request/response bodies. Standard HTTP status codes.
- **Tests**: Write tests alongside implementation. Pytest for Python, XCTest for iOS.
- **Commits**: Conventional commits (`feat:`, `fix:`, `chore:`, `docs:`).
