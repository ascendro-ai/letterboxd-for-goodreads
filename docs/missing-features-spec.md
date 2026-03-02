# Missing Features Spec — Items Not Yet in Worktree Scope

These six features are defined in `technical-decisions-final.md` but have no models, endpoints, or implementation guidance in the current worktree CLAUDE.md files. Each section below provides enough detail to build against.

---

## 1. Waitlist & Invite Codes

**Why:** Launch strategy is waitlist + invite codes (Beli model). Users join a waitlist, receive an invite code, and each invited user gets 5–6 codes to share.

### Database Tables

```
waitlist
  - id (UUID, PK)
  - email (unique, indexed)
  - created_at
  - invited_at (nullable — set when code is sent)
  - invite_code_id (FK → invite_codes, nullable)

invite_codes
  - id (UUID, PK)
  - code (varchar(12), unique, indexed) — short alphanumeric, e.g. "SHELF-A3K9"
  - created_by_user_id (FK → users, nullable — null for system-generated codes)
  - claimed_by_user_id (FK → users, nullable)
  - created_at
  - claimed_at (nullable)
  - expires_at (nullable)
```

### API Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/waitlist` | Public | Join waitlist (email) |
| POST | `/auth/signup` | Public | Extended — requires `invite_code` field in body |
| GET | `/me/invite-codes` | Required | List my invite codes (granted on signup) |

### Business Rules

- On signup, validate `invite_code` exists, is unclaimed, and is not expired.
- On successful signup, mark code as claimed and generate 5 new codes for the new user.
- System-generated codes (for waitlist invitations) have `created_by_user_id = null`.
- Admin tooling for bulk-generating codes is out of scope for v1 — use a DB script.

### Ownership

- **Models & migrations:** `backend/database`
- **Endpoints & service logic:** `backend/api-core` (extend `auth.py`, new `waitlist.py` route)
- **iOS:** `ios/core` — invite code field on signup screen, "My Invite Codes" section in profile/settings with share sheet

---

## 2. Data Export

**Why:** Spec requires "JSON self-serve export from day one" for GDPR compliance and user trust.

### API Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/me/export` | Required | Request data export (kicks off background job) |
| GET | `/me/export/status` | Required | Check export status |
| GET | `/me/export/download` | Required | Download export file (signed URL, expires in 24h) |

### Export Contents

Single JSON file containing:

```json
{
  "exported_at": "2026-03-02T12:00:00Z",
  "user": { "username", "display_name", "bio", "created_at" },
  "books": [
    {
      "title", "authors", "status", "rating", "review_text",
      "has_spoilers", "started_at", "finished_at", "created_at"
    }
  ],
  "shelves": [
    { "name", "description", "is_public", "books": ["title", ...] }
  ],
  "following": ["username", ...],
  "followers": ["username", ...]
}
```

### Business Rules

- Rate limit: 1 export request per 24 hours per user.
- Export runs as a background job. Store output in R2 with a signed download URL.
- Signed URL expires after 24 hours. User can re-request.
- No passwords, auth tokens, or internal IDs in the export.

### Ownership

- **Models & migrations:** `backend/database` — add `export_requests` table (id, user_id, status, file_url, created_at, expires_at)
- **Endpoint & service:** `backend/api-core` — new `export.py` route, `export_service.py`
- **iOS:** `ios/core` — "Export My Data" button in Settings

---

## 3. Report an Issue (Book Metadata)

**Why:** No community edits at launch. Instead, a "Report an issue" button feeds a manual review queue.

### Database Table

```
metadata_reports
  - id (UUID, PK)
  - reporter_user_id (FK → users)
  - work_id (FK → works)
  - issue_type (enum: wrong_cover, wrong_author, wrong_title, wrong_description, duplicate, other)
  - description (text — user's explanation)
  - status (enum: open, reviewed, resolved, dismissed)
  - reviewed_by (nullable — admin user ID)
  - created_at
  - resolved_at (nullable)
```

### API Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/books/{work_id}/report` | Required | Submit metadata issue report |

### Request Body

```json
{
  "issue_type": "wrong_cover",
  "description": "This cover belongs to a different edition."
}
```

### Business Rules

- Rate limit: 10 reports per user per day.
- Deduplicate: if an open report for the same work + issue_type exists from the same user, return 409.
- Admin review UI is out of scope for v1 — review via direct DB queries or a simple admin script.
- No notification back to the reporter when resolved (v1).

### Ownership

- **Models & migrations:** `backend/database`
- **Endpoint:** `backend/api-core` — add to `books.py` routes
- **iOS:** `ios/core` — "Report an Issue" button on BookDetail screen (action sheet with issue type picker + text field)

---

## 4. Content Moderation

**Why:** Spec requires AI moderation on review submission + community flagging + manual review.

### Database Table

```
review_flags
  - id (UUID, PK)
  - flagger_user_id (FK → users)
  - user_book_id (FK → user_books) — the review being flagged
  - reason (enum: spam, harassment, spoilers, hate_speech, other)
  - description (text, optional — user's explanation)
  - status (enum: pending, reviewed, removed, dismissed)
  - reviewed_by (nullable)
  - created_at
  - resolved_at (nullable)
```

### API Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/reviews/{user_book_id}/flag` | Required | Flag a review |

### AI Moderation (on submission)

When a user submits or updates a review (`POST /me/books` or `PATCH /me/books/{id}` with `review_text`):

1. Run `review_text` through moderation check **before** saving.
2. Use OpenAI Moderation API (free) as primary. Perspective API as fallback/secondary signal.
3. If flagged: reject with 422 and `"error": {"code": "REVIEW_FLAGGED", "message": "Your review was flagged for potentially violating community guidelines."}`.
4. If borderline: save but auto-insert into review queue with `status: pending`.

### Business Rules

- Users cannot flag their own reviews.
- 1 flag per user per review (return 409 on duplicate).
- After 3 unique flags on a review, auto-hide it pending manual review.
- Moderation service is behind `services/moderation_service.py` — abstract provider so it's swappable.

### Ownership

- **Models & migrations:** `backend/database`
- **Endpoint & service:** `backend/api-core` — `moderation_service.py` (already in file tree), add flag route
- **iOS:** `ios/core` — "Report Review" option in review overflow menu (three-dot menu on review cards)

---

## 5. Friend Discovery & Contacts Sync

**Why:** Spec says "Prompt friend discovery during onboarding (contacts sync + taste-similar users from import)."

### API Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/me/discover/contacts` | Required | Upload hashed phone numbers / emails, get matched users |
| GET | `/me/discover/taste` | Required | Get users with high taste match scores (from import data) |
| GET | `/me/discover/popular` | Required | Suggested popular/active users to follow |

### Contacts Sync Flow

1. iOS requests Contacts permission during onboarding.
2. Client hashes phone numbers and emails with SHA-256 **on device** before sending.
3. Backend compares hashed values against a `user_contact_hashes` table.
4. Returns list of matching Shelf users (id, username, avatar, taste match score if available).

### Database Table

```
user_contact_hashes
  - user_id (FK → users)
  - hash (varchar(64), indexed) — SHA-256 of normalized phone/email
  - hash_type (enum: phone, email)
  - created_at
  - unique constraint on (hash, hash_type)
```

### Business Rules

- Hashing happens client-side. Backend never sees raw contact data.
- User stores their own hashes on signup (from their own phone number + email).
- Contact upload is optional and one-time during onboarding. Can be re-triggered from settings.
- Taste-based discovery: return top 20 users sorted by `taste_matches.match_score DESC` who the current user does not already follow.
- Popular users: curated seed list at launch, then switch to "most followed this week."

### Ownership

- **Models & migrations:** `backend/database`
- **Endpoint & service:** `backend/api-core` — new `discover.py` route, `discover_service.py`
- **iOS:** `ios/core` — onboarding flow screen after import: "Find Friends" → contacts permission → results list with follow buttons

---

## 6. Reserved Username List

**Why:** Spec says usernames must block reserved words to prevent impersonation and confusion.

### Implementation

A static list maintained in the backend, checked at signup and username change.

### File: `backend/services/reserved_usernames.py`

```python
RESERVED_USERNAMES: set[str] = {
    # Product / brand
    "shelf", "shelfapp", "admin", "administrator", "moderator", "mod",
    "support", "help", "official", "team", "staff", "system",

    # Routes / URL conflicts
    "api", "auth", "login", "signup", "register", "settings", "profile",
    "feed", "search", "explore", "discover", "import", "export",
    "notifications", "messages", "books", "shelves", "users", "me",

    # Common reserved
    "root", "null", "undefined", "anonymous", "deleted", "unknown",
    "test", "demo", "example", "info", "contact", "about", "terms",
    "privacy", "legal", "copyright", "blog", "news", "press",

    # Social / impersonation prevention
    "goodreads", "storygraph", "letterboxd", "amazon", "kindle",
    "audible", "libby", "kobo", "apple", "google", "bookstagram",
    "booktok",
}


def is_username_reserved(username: str) -> bool:
    return username.lower().strip() in RESERVED_USERNAMES
```

### Validation Rules

- Check during `POST /auth/signup` and `PATCH /me` (username change).
- Case-insensitive comparison.
- Return 422 with `"error": {"code": "USERNAME_RESERVED", "message": "This username is not available."}`.
- Also enforce: 3–20 characters, alphanumeric + underscores only, cannot start/end with underscore, no consecutive underscores.

### Ownership

- **Validation logic:** `backend/api-core` — `reserved_usernames.py` in services, called from auth + user routes
- **iOS:** `ios/core` — real-time username availability check on signup (debounced API call as user types)

---

## Implementation Priority

| Priority | Feature | Reason |
|----------|---------|--------|
| **P0 — Launch blocker** | Reserved Usernames (#6) | Trivial to build, painful to fix later |
| **P0 — Launch blocker** | Waitlist & Invite Codes (#1) | Required for launch strategy |
| **P1 — Launch day** | Content Moderation (#4) | Can't ship reviews without moderation |
| **P1 — Launch day** | Data Export (#2) | GDPR compliance commitment |
| **P2 — First week** | Report an Issue (#3) | Low effort, needed for data quality |
| **P2 — First week** | Friend Discovery (#5) | Important for onboarding but can soft-launch without |
