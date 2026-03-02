# Shelf — Letterboxd for Books

A Letterboxd-style iOS app for tracking books. Monorepo: FastAPI backend, SwiftUI iOS app, Open Library data pipeline.

## Architecture

```
iOS App (SwiftUI) ──▶ FastAPI Backend (Railway) ──▶ Supabase Postgres
       │                      │                           │
       ▼                      ▼                           ▼
  RevenueCat            Supabase Auth              Cloudflare R2
  (payments)            (JWT provider)             (cover images)
                              │
                    Data Pipeline (Railway cron)
                    - OL bulk import, nightly sync
                    - Cover processing, taste matches
```

## Current State — What's Built

**Backend (28 test files):** 17 route files, 26 services, 19 schema files, all with real business logic. Auth (email/Apple/Google via Supabase), book search/detail/ISBN, reading log CRUD with per-book privacy, shelves, social graph (follow/block/mute), activity feed (fan-out-on-read), Goodreads/StoryGraph/Kindle/Kobo import, push notifications (APNs), content moderation (OpenAI + Perspective API), data export (R2), reading challenges, series tracking, reading stats, community content tags (content warnings + mood tags with voting), waitlist/invite system, RevenueCat webhooks, admin moderation panel.

**iOS App (78 real Swift files):** Full 5-tab app (Feed/Search/Log/Notifications/Profile). 10 models, 18 services, 8 view models, 30 views, 12 components. Real APIClient with JWT auth, offline queue (SwiftData) with cache fallback and conflict handling, network monitor sync. All views implemented: barcode scanner (VisionKit + AVFoundation fallback), half-star rating input, LogBookSheet with privacy toggle, import flow with progress, paywall (RevenueCat), onboarding, deep linking (`shelf://` URL scheme), share extension with Goodreads/Google Books URL parsing, cold start feed, reading stats with Charts, content tag voting, series tracking, reading challenges, accessibility modifiers throughout. AdMob integration coded with `#if canImport(GoogleMobileAds)` guards. SPM deps: Supabase 2.41, RevenueCat 5.60, PostHog 3.42, Sentry 8.58.

**Pipeline:** Bulk OL import (streaming TSV+JSON, COPY inserts, UNLOGGED staging), nightly sync (Recent Changes API), cover processing (OL → Google Books fallback, WebP, 4 size variants, R2 upload), taste match computation.

**Infrastructure:** Docker (backend + pipeline), Railway configs, GitHub Actions CI/CD (lint + test on PR, deploy on push to main), docker-compose for local Postgres.

## Monorepo Structure

```
backend/
  api/routes/       17 route files (auth, books, user_books, shelves, feed, users, import_,
                     moderation, notifications, waitlist, export, discover, webhooks, admin,
                     series, challenges, stats)
  api/schemas/       19 Pydantic schema files matching every route
  api/model_stubs.py Temporary SQLite-compatible ORM stubs (services import from here)
  api/config.py      30+ settings from env vars (cached @lru_cache)
  models/            Canonical Postgres-native ORM (base, work, user, user_book, social, taste_match)
  services/          26 service files with all business logic
  migrations/        5 Alembic migrations (initial schema, is_deleted, series+challenges,
                     privacy+stats+content_tags, missing tables+is_hidden)
  tests/             28 test files (SQLite in-memory)
pipeline/
  import_ol/         bulk_import, parse_works/authors/editions, dedup, helpers
  cover_processing/  fetch_covers, format (WebP), resize (4 variants), upload_r2
  sync/              nightly_sync, taste_match_job, live_fallback
  tests/             test_bulk_import + fixtures (cover/sync tests missing)
ios/Shelf/
  Models/            10 model files (Book, UserBook, User, Feed, Shelf, Series, Challenge, APIModels,
                     ReadingStats, ContentTag)
  Services/          18 service files (APIClient, Auth, Offline, Sync, Book, UserBook, Shelf,
                     Feed, Social, Import, Analytics, Subscription, Ad, Notification, Series,
                     Challenge, DeepLinkHandler, SharedStorage)
  ViewModels/        8 view models (BookDetail, Feed, Search, Profile, Import, Notifications,
                     BarcodeScanner, Stats)
  Views/             30 views across Auth/, Feed/, BookDetail/, Search/, Profile/, Shelves/, Social/,
                     Import/, Series/, Challenges/
  Components/        12 reusable components (StarRating, BookCard, BookCoverImage, SeriesBadge,
                     OfflineBannerView, DiscoverPromptCard, etc.)
infra/
  docker/            Dockerfile.backend, Dockerfile.pipeline, entrypoint
  railway/           railway.toml (backend), railway-pipeline.toml (cron)
.github/workflows/   backend-ci, pipeline-ci, ios-ci, deploy
```

## Critical Blockers Before Launch

### ~~1. Missing Database Tables~~ (FIXED)
~~9 missing tables~~ — Migration `d4e5f6a7b8c9` now creates all 9 (notifications, device_tokens, import_jobs, review_flags, metadata_reports, waitlist, invite_codes, export_requests, user_contact_hashes) and adds `is_hidden` to user_books.

### ~~2. model_stubs.py Divergence~~ (FIXED)
~~Enum mismatch~~ — Initial migration now uses `String` columns instead of Postgres enums for `activity_type`, `status`, and `format`, matching model_stubs.py.

### 3. No Book Catalog (BLOCKER)
Database starts empty. Must run OL bulk import before any user can search/log books. Multi-hour process (~40GB download). Not a code issue — an ops task.

### 4. AdMob SPM Package Not Added (MEDIUM)
AdMob Swift code is complete: `AdService.swift` has full `GADAdLoader` integration with ad preloading pool and delegate conformance, `NativeAdCardView.swift` wraps `GADNativeAdView` via `UIViewRepresentable` — all behind `#if canImport(GoogleMobileAds)` guards so it compiles without the SDK. **Remaining step:** add GoogleMobileAds SPM package in Xcode. App ID and Ad Unit ID are configured in Info.plist.

### 5. Google Sign In Not Wired on iOS (HIGH)
Backend supports Google OAuth. iOS `AuthService.signInWithGoogle()` exists but needs Google Sign-In SDK + `GoogleService-Info.plist`. Apple Sign In works.

### 6. Missing API Credentials (HIGH)
- Sentry DSN: empty in both backend `.env` and iOS `AnalyticsService.swift`
- OpenAI API key: empty (moderation degrades gracefully but reviews are unscreened)
- APNs: needs `.p8` key file, key ID, team ID from Apple Developer account
- RevenueCat: using `test_` key, need production key for real payments

## Business Rules

- **Review required for ratings** — new ratings must include review text. Imports exempt.
- **Block cascades** — blocking auto-unfollows both directions, clears mutes.
- **Feed filtering** — only "reading" and "read" create Activity. "want_to_read" and "did_not_finish" are silent. Private books never create Activity.
- **Per-book privacy** — books marked `is_private` are hidden from other users' views, excluded from feed, and filtered from public reviews. Owner always sees their own private books.
- **Content tags** — community-voted tags from a predefined taxonomy (20 content warnings + 20 moods). Confirmed at 3 votes. One vote per user per tag per book.
- **Reading stats visibility** — users can set `hide_reading_stats` to prevent others from seeing their stats. Returns 404 (not 403) to avoid leaking existence.
- **Shelf limits** — 20 free, unlimited premium. Status shelves (read/reading/etc) are fields, not shelves.
- **Soft delete** — users soft-deleted, reviews anonymized, GDPR-compliant 12-step cascade.
- **Import matching** — ISBN-13 → ISBN-10 → exact title → ILIKE fuzzy. Order matters.
- **Taste match** — only computed for pairs sharing 5+ rated books.
- **Invite-gated beta** — signup requires an invite code. Each new user gets 5 codes.

## Conventions

- **Python**: ruff, type hints everywhere, async endpoints, SQLAlchemy 2.0 mapped_column
- **Swift**: SwiftUI-first, @Observable (not @Published), iOS 17+, SwiftData for offline
- **Database**: snake_case, UUIDs for PKs, Alembic for schema changes
- **API**: RESTful, `/api/v1/`, JSON, cursor-keyset pagination (base64 opaque)
- **Tests**: pytest (SQLite in-memory), XCTest (iOS), conventional commits
- **Errors**: `AppError(status_code, code, message)` → `{"error": {"code": ..., "message": ...}}`

## Running Locally

```bash
# Postgres
docker-compose up -d

# Backend
cd backend && python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt && alembic upgrade head
uvicorn api.main:app --reload --port 8000

# Pipeline (one-time bulk import)
cd pipeline && python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python -m import_ol.bulk_import --authors authors.tsv.gz --works works.tsv.gz --editions editions.tsv.gz

# Tests
cd backend && pytest tests/ -v  # 266 tests
cd pipeline && pytest tests/ -v

# iOS — open ios/Shelf/Shelf.xcodeproj in Xcode (iOS 17+ simulator)
```

## Environment Variables (configured in .env files)

**Backend:** DATABASE_URL, SUPABASE_URL, SUPABASE_SERVICE_KEY, SUPABASE_JWT_SECRET, SENTRY_DSN, CLOUDFLARE_R2_ENDPOINT, CLOUDFLARE_R2_ACCESS_KEY, CLOUDFLARE_R2_SECRET_KEY, POSTHOG_API_KEY, POSTHOG_HOST, OPENAI_API_KEY, BOOKSHOP_AFFILIATE_ID, REVENUECAT_WEBHOOK_SECRET, APNS_KEY_ID, APNS_TEAM_ID, APNS_KEY_PATH, DEV_AUTH_BYPASS, ENVIRONMENT

**Pipeline:** DATABASE_URL (psycopg sync), CLOUDFLARE_R2_ENDPOINT, CLOUDFLARE_R2_ACCESS_KEY, CLOUDFLARE_R2_SECRET_KEY, CLOUDFLARE_R2_BUCKET, GOOGLE_BOOKS_API_KEY

## Next Steps (Priority Order)

1. ~~**Write migration for missing tables**~~ — DONE (migration `d4e5f6a7b8c9`)
2. ~~**Resolve model_stubs ↔ migrations enum mismatch**~~ — DONE (initial migration uses String, not Enum)
3. **Run OL bulk import** — download dumps, run pipeline, then cover processing
4. **Add GoogleMobileAds SPM package in Xcode** — Swift code is complete (`#if canImport` guards), just add the SPM dependency
5. **Add Google Sign-In SDK** — add SPM package + GoogleService-Info.plist
6. **Get APNs credentials** — .p8 key from Apple Developer, set APNS_KEY_ID/TEAM_ID/KEY_PATH
7. **Switch RevenueCat to production** — replace test_ key with real key
8. **Set Sentry DSN** — create project at sentry.io, add DSN to backend .env + iOS
9. **Set OpenAI key** — for review content moderation
10. **End-to-end test against real Postgres** — verify all 17 route groups work with real schema
11. **App Store prep** — screenshots, description, privacy policy, TestFlight build
