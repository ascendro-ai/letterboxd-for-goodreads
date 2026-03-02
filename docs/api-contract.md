# API Contract — v1

Base URL: `/api/v1`

All endpoints require `Authorization: Bearer <supabase_jwt>` unless marked public.

---

## Auth

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/auth/signup` | Public | Create account (email+password) |
| POST | `/auth/login` | Public | Login (email+password) |
| POST | `/auth/apple` | Public | Apple Sign In token exchange |
| POST | `/auth/google` | Public | Google Sign In token exchange |
| POST | `/auth/refresh` | Public | Refresh JWT |
| DELETE | `/auth/account` | Required | Soft delete account |

---

## Books

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/books/search?q={query}` | Required | Search books (FTS + fuzzy) |
| GET | `/books/{work_id}` | Required | Book detail |
| GET | `/books/isbn/{isbn}` | Required | Lookup by ISBN (barcode) |
| GET | `/books/{work_id}/reviews` | Required | Reviews for a book |
| GET | `/books/{work_id}/similar` | Required | "People who liked this also liked..." |
| GET | `/books/popular` | Required | Popular this week (cold start feed) |

### Book Detail Response

```json
{
  "id": "uuid",
  "title": "string",
  "original_title": "string | null",
  "description": "string | null",
  "first_published_year": 2020,
  "authors": [{"id": "uuid", "name": "string"}],
  "subjects": ["fiction", "dystopian"],
  "cover_image_url": "https://cdn.shelf.app/covers/{id}/detail.webp",
  "average_rating": 4.2,
  "ratings_count": 1523,
  "editions_count": 12,
  "bookshop_url": "https://bookshop.org/...?affiliate=shelf"
}
```

---

## User Books (Logging)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/me/books` | Required | Log a book (rate, review, set status) |
| PATCH | `/me/books/{user_book_id}` | Required | Update rating, review, status |
| DELETE | `/me/books/{user_book_id}` | Required | Remove from library |
| GET | `/me/books?status={status}` | Required | List my books (filterable) |
| GET | `/users/{user_id}/books?status={status}` | Required | List another user's books |

### Log Book Request

```json
{
  "work_id": "uuid",
  "status": "read",
  "rating": 4.5,
  "review_text": "Incredible world-building...",
  "has_spoilers": false,
  "started_at": "2024-01-15",
  "finished_at": "2024-02-01"
}
```

---

## Shelves

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/me/shelves` | Required | Create shelf |
| GET | `/me/shelves` | Required | List my shelves |
| PATCH | `/me/shelves/{shelf_id}` | Required | Update shelf |
| DELETE | `/me/shelves/{shelf_id}` | Required | Delete shelf |
| POST | `/me/shelves/{shelf_id}/books` | Required | Add book to shelf |
| DELETE | `/me/shelves/{shelf_id}/books/{user_book_id}` | Required | Remove book from shelf |
| GET | `/users/{user_id}/shelves` | Required | List another user's public shelves |
| GET | `/users/{user_id}/shelves/{shelf_id}` | Required | View shelf detail |

---

## Social

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/users/{user_id}/follow` | Required | Follow user |
| DELETE | `/users/{user_id}/follow` | Required | Unfollow user |
| GET | `/users/{user_id}/followers` | Required | List followers |
| GET | `/users/{user_id}/following` | Required | List following |
| POST | `/users/{user_id}/block` | Required | Block user |
| DELETE | `/users/{user_id}/block` | Required | Unblock user |
| POST | `/users/{user_id}/mute` | Required | Mute user |
| DELETE | `/users/{user_id}/mute` | Required | Unmute user |
| GET | `/me/taste-matches` | Required | List taste matches |

---

## Feed

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/feed?cursor={cursor}` | Required | Activity feed (cursor-based pagination) |
| GET | `/notifications?cursor={cursor}` | Required | Notifications |
| POST | `/notifications/read` | Required | Mark notifications as read |

### Feed Item Response

```json
{
  "id": "uuid",
  "user": {"id": "uuid", "username": "string", "avatar_url": "string"},
  "activity_type": "finished_book",
  "book": {"id": "uuid", "title": "string", "cover_image_url": "string"},
  "rating": 4.5,
  "review_text": "string | null",
  "has_spoilers": false,
  "created_at": "2024-02-01T12:00:00Z"
}
```

---

## Users / Profile

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/me` | Required | My profile |
| PATCH | `/me` | Required | Update profile |
| GET | `/users/{user_id}` | Required | View user profile |
| GET | `/users/search?q={query}` | Required | Search users |

---

## Import

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/me/import/goodreads` | Required | Upload Goodreads CSV |
| POST | `/me/import/storygraph` | Required | Upload StoryGraph CSV |
| GET | `/me/import/status` | Required | Check import progress |

### Import Status Response

```json
{
  "status": "processing",
  "total_books": 847,
  "matched": 812,
  "needs_review": 23,
  "unmatched": 12,
  "progress_percent": 67
}
```

---

## Pagination

All list endpoints use cursor-based pagination:

```
GET /feed?cursor=eyJjcmVhdGVkX2F0IjoiMjAyNC0wMi0wMSJ9&limit=20
```

Response includes:
```json
{
  "items": [...],
  "next_cursor": "string | null",
  "has_more": true
}
```

---

## Error Format

```json
{
  "error": {
    "code": "BOOK_NOT_FOUND",
    "message": "No book found with the given ID."
  }
}
```

Standard HTTP status codes: 200, 201, 400, 401, 403, 404, 409, 422, 429, 500.
