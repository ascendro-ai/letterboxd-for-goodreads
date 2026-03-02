# [Working Title: Shelf] — Technical Decisions Document

All decisions made. This is the canonical reference for building the product.

---

## Product Decisions

| Decision | Answer |
|----------|--------|
| Platform | iOS only (native Swift) |
| Launch strategy | Waitlist + invite codes (Beli model) |
| Minimum iOS | 17+ |
| Free vs. premium | Free with ads + $4.99/mo or $39.99/yr premium (ad-free + extra features) |
| Monetization | AdMob native feed ads (free tier) + RevenueCat subscriptions + Bookshop.org affiliate links |
| Incorporation | Texas C-Corp |

---

## Data Architecture

### Book Data Model

**Logging unit: Work-level** (like Letterboxd — one page per book, all ratings aggregate there). Users can optionally set a preferred cover for display. Editions exist for search/matching but are not the unit of logging.

**Canonical identifier: Internal UUID.** Open Library work ID, Google Books ID, and ISBN-13 (array) stored as indexed secondary columns for lookups and deduplication.

**Initial catalog: Full Open Library bulk import** (~40GB, 30M+ works). Comprehensive from day one — enables fast Goodreads import matching against local data.

**Catalog sync: Nightly** via Open Library's recent changes API. New books appear within 24 hours. Fallback to live API call if a user searches for something not yet synced.

**Books without ISBNs:** Covered if Open Library has them. No user submission flow at launch.

**Community edits to metadata:** Not at launch. "Report an issue" button that drops into a manual review queue.

**Series data:** Skipped at launch. Not core to logging or social.

**Chapter data:** Skipped entirely. No page-gated spoiler reactions, no per-chapter discussion threads.

### Cover Images

**Storage:** Cloudflare R2 + Cloudflare CDN. Free egress.

**Pipeline:** During bulk import and nightly sync, fetch best available cover from Open Library → Google Books → store original in R2 → generate responsive variants (thumbnail 150px, card 300px, detail 600px, hero 1200px). Background job.

**Format:** WebP with JPEG fallback.

**Missing covers:** Single generic "no cover" placeholder image.

### Core Database Tables

```
works
  - id (UUID, primary key)
  - title
  - original_title
  - description
  - first_published_year
  - open_library_work_id (indexed)
  - google_books_id (indexed)
  - subjects/genres (array)
  - cover_image_url
  - average_rating (community)
  - ratings_count
  - created_at, updated_at
  - tsvector index on title (for FTS)
  - trigram index on title, author (for fuzzy matching)

editions
  - id (UUID)
  - work_id (FK → works)
  - isbn_10, isbn_13 (both indexed)
  - publisher, publish_date, page_count
  - format (hardcover, paperback, ebook, audiobook)
  - language
  - cover_image_url
  - open_library_edition_id

authors
  - id (UUID)
  - name
  - bio, photo_url
  - open_library_author_id
  - trigram index on name

users
  - id (UUID, from Supabase Auth)
  - username (unique, required at signup)
  - display_name, avatar_url, bio
  - favorite_books (array of 4 work UUIDs)
  - created_at

user_books
  - id, user_id, work_id
  - status (reading, read, want_to_read, did_not_finish)
  - rating (decimal, 0.5 increments, range 0.5–5.0)
  - review_text (required for new ratings, exempt for imports)
  - has_spoilers (boolean)
  - started_at, finished_at
  - is_imported (boolean)
  - created_at, updated_at

shelves
  - id, user_id, name, slug, description
  - is_public (default true, user can make private)
  - display_order
  - max 20 per user (premium unlocks more)

shelf_books
  - shelf_id, user_book_id, position

follows
  - follower_id, following_id, created_at

activities
  - id, user_id
  - activity_type (finished_book, started_book)
  - target_id (user_book_id)
  - metadata (jsonb)
  - created_at
  - index on (user_id, created_at)

taste_matches (precomputed nightly)
  - user_a_id, user_b_id
  - match_score (decimal)
  - overlapping_books_count
  - computed_at
  - minimum 5 shared rated books to generate

blocks
  - blocker_id, blocked_id, created_at

mutes
  - muter_id, muted_id, created_at
```

---

## Search

**Launch: PostgreSQL full-text search (tsvector) + pg_trgm extension** for fuzzy matching. Trigram GIN indexes on title and author columns. Handles moderate typos.

**Migration plan:** Add Typesense Cloud within first 3 months based on user feedback. Search queries abstracted behind a service layer for easy backend swap.

**Barcode scanning:** Built-in at launch via Apple VisionKit/AVFoundation. ISBN from barcode → edition table → resolve to work.

---

## Goodreads & StoryGraph Import

**Supported sources:** Goodreads CSV + StoryGraph CSV at launch. One-time onboarding action (no re-import support at launch).

**Matching waterfall:**
```
ISBN-13 → ISBN-10 → exact title+author → fuzzy title+author (0.85+ threshold, both fields required) → flag as unmatched
```

**Processing:** Background job with progress updates. User can browse the app while import runs. Push notification when complete with summary (matched, needs help, unmatched).

**Import details:**
- Parse Goodreads `="ISBN"` quoting format
- Map Goodreads integer ratings to our half-star scale as-is (4 → 4.0)
- Preserve review text (imported reviews exempt from "review required" rule)
- Map Goodreads shelves: read → Read, currently-reading → Currently Reading, to-read → Want to Read, custom → create matching shelves
- Handle Bookshelves + Exclusive Shelf column distinction
- Target: 1000+ book libraries complete in under 60 seconds

---

## Social & Feed

**Feed generation:** Simple JOIN query at read time (fan-out on read). `SELECT activities FROM activities JOIN follows WHERE follower_id = current_user ORDER BY created_at DESC`. Chronological, no algorithmic ranking. Optimize later when slow.

**Activity types in feed:** Finished a book (with rating + review) and Started reading a book. Only two event types — high signal, no noise.

**Cold start:** Show "popular this week" global feed until user follows enough people. Prompt friend discovery during onboarding (contacts sync + taste-similar users from import).

**Taste match algorithm (v1):**
```
For two users A and B:
  1. Find all works both have rated
  2. If < 5 shared works, no score
  3. For each shared work, compute |rating_A - rating_B|
  4. Match score = 1 - (avg_difference / max_possible_difference)
  5. Weight by number of shared books
  6. Recompute nightly batch job
```

**Recommendations:** Simple item-based collaborative filtering at launch — "people who rated this highly also rated..." Import data provides immediate signal.

**Notifications:** Push (APNs) + in-app notification bell. Batched ("3 friends finished books today"). No email at launch.

---

## Ratings & Reviews

| Setting | Value |
|---------|-------|
| Rating granularity | Half-star (0.5 increments), stored as decimal |
| Review required for new ratings | Yes (imported books exempt) |
| Spoiler handling | Whole-review toggle, hidden behind tap-to-reveal |
| Author accounts | Not at launch — authors are metadata only |
| Author-reviewer interaction | N/A at launch; future policy: Letterboxd model (can see, can't respond) |

---

## Accounts & Auth

| Setting | Value |
|---------|-------|
| Auth provider | Supabase Auth |
| Login methods | Apple Sign In, Google Sign In, Email + password |
| Username | Required at signup, unique, reserved words list |
| Account deletion | Soft delete — anonymize to "deleted user", reviews/ratings persist |
| Session management | Handled by Supabase Auth |

---

## Shelves

| Setting | Value |
|---------|-------|
| Max custom shelves | 20 (premium unlocks more) |
| Privacy | Public by default, per-shelf private toggle |
| Books on multiple shelves | Yes (plus one exclusive status: reading/read/want/DNF) |

---

## Content Moderation

| Setting | Value |
|---------|-------|
| Approach | AI moderation on submission (Perspective API / OpenAI moderation) + community flagging + manual review |
| Block | Full separation — can't see each other's profiles or reviews |
| Mute | Hidden from your feed, they don't know |

---

## Tech Stack

### Frontend (iOS)
- **Language:** Swift
- **UI Framework:** SwiftUI primary, UIKit for complex components (cover grid, custom transitions, rating input)
- **Minimum iOS:** 17+
- **Offline support:** Yes — log books, rate, browse shelf offline. SwiftData/Core Data for local persistence, sync queue on reconnect.
- **Barcode scanning:** Apple VisionKit / AVFoundation
- **Design:** Built directly in SwiftUI with live previews (no Figma)
- **Ads:** Google AdMob native ads in feed
- **Payments:** RevenueCat wrapping StoreKit
- **Share extension:** Yes — share book links from Safari/Instagram into the app

### Backend
- **Language:** Python (FastAPI)
- **ORM:** SQLAlchemy with parameterized queries
- **API style:** REST
- **Hosting:** Railway (deploy from GitHub)
- **Background jobs:** Railway cron jobs + Python asyncio (no job queue framework)
- **Caching:** None at launch — Postgres with good indexes. Add Redis when needed.

### Database
- **Provider:** Supabase managed Postgres (Pro tier, $25/mo + storage overages for 30M+ works)
- **Extensions:** pg_trgm (fuzzy matching), tsvector (full-text search)
- **Search migration plan:** Typesense Cloud within 3 months if search quality insufficient

### Infrastructure
- **Cover image storage:** Cloudflare R2 + Cloudflare CDN
- **Auth:** Supabase Auth
- **Error tracking:** Sentry (iOS + backend)
- **Product analytics:** Posthog
- **Source control:** GitHub
- **CI/CD:** GitHub Actions

---

## Privacy & Legal

| Setting | Value |
|---------|-------|
| Incorporation | Texas C-Corp |
| Data export | JSON self-serve export from day one |
| GDPR compliance | Soft delete with anonymization, data export, consent flows |
| Internationalization | English UI, non-English books supported in catalog |
| Accessibility | WCAG AA, VoiceOver, iOS Dynamic Type |
| Password storage | Handled by Supabase Auth |

---

## Testing

| Setting | Value |
|---------|-------|
| Strategy | Full test coverage from day one |
| Backend | Pytest (unit + integration) |
| iOS | XCTest |
| Import pipeline | Dedicated corpus of 20+ real Goodreads/StoryGraph CSVs with edge cases |

---

## Monetization

| Revenue Stream | Details |
|----------------|---------|
| Premium subscriptions | $4.99/mo or $39.99/yr via RevenueCat + StoreKit. Ad-free + extra features (more shelves, advanced stats, custom profile themes, enhanced year-in-review). |
| Ads (free tier) | Google AdMob native ads styled as feed cards, every 8-10 items |
| Affiliate | Bookshop.org affiliate links on book pages (~10% commission) |

---

## Launch Plan

1. **Build phase** — iOS app + FastAPI backend + Open Library bulk import + import pipeline
2. **TestFlight beta** — 200-500 invited users (BookTok/Bookstagram creators), stress test import, gather design feedback
3. **Waitlist launch** — App Store listing with waitlist signup, invite code distribution (5-6 codes per user)
4. **Open launch** — Remove invite gate when community is self-sustaining

---

## Estimated Monthly Costs at Launch

| Service | Cost |
|---------|------|
| Supabase Pro (Postgres + Auth) | ~$28/mo |
| Railway (FastAPI + cron jobs) | ~$20/mo |
| Cloudflare R2 (cover storage) | ~$5-15/mo |
| Sentry (free tier) | $0 |
| Posthog (free tier) | $0 |
| Apple Developer Program | $99/yr |
| RevenueCat (free under $2.5K MTR) | $0 |
| Google AdMob | $0 (revenue generating) |
| **Total** | **~$55-65/mo** |

---

## Open Questions (Deferred)

- Final product name + domain
- Premium feature set (exact gates between free and paid)
- When to add Typesense (based on search quality feedback)
- When to add Android
- Author profiles and claimed accounts
- E-reader integrations (Kindle, Kobo, Libby)
- Reading challenges and goals
- Content warnings system
- Smart/dynamic shelves
- Collaborative shelves
- User-submitted books for missing catalog entries
- Re-import support
- Series data
- Community metadata editing
