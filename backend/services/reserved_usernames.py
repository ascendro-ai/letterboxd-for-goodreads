from __future__ import annotations

import re

RESERVED_USERNAMES: frozenset[str] = frozenset(
    {
        # Product / brand
        "shelf",
        "shelfapp",
        "admin",
        "administrator",
        "moderator",
        "mod",
        "support",
        "help",
        "official",
        "team",
        "staff",
        "system",
        # Routes / URL conflicts
        "api",
        "auth",
        "login",
        "signup",
        "register",
        "settings",
        "profile",
        "feed",
        "search",
        "explore",
        "discover",
        "import",
        "export",
        "notifications",
        "messages",
        "books",
        "shelves",
        "users",
        "me",
        # Common reserved
        "root",
        "null",
        "undefined",
        "anonymous",
        "deleted",
        "unknown",
        "test",
        "demo",
        "example",
        "info",
        "contact",
        "about",
        "terms",
        "privacy",
        "legal",
        "copyright",
        "blog",
        "news",
        "press",
        # Social / impersonation prevention
        "goodreads",
        "storygraph",
        "letterboxd",
        "amazon",
        "kindle",
        "audible",
        "libby",
        "kobo",
        "apple",
        "google",
        "bookstagram",
        "booktok",
    }
)

_USERNAME_PATTERN = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9_]*[a-zA-Z0-9]$|^[a-zA-Z0-9]$")
_CONSECUTIVE_UNDERSCORES = re.compile(r"__")

USERNAME_MIN_LENGTH = 3
USERNAME_MAX_LENGTH = 20


def is_username_reserved(username: str) -> bool:
    """Return True if the username is in the reserved blocklist (case-insensitive)."""
    return username.strip().lower() in RESERVED_USERNAMES


def validate_username_format(username: str) -> str | None:
    """Validate username format rules.

    Returns an error message string if the username is invalid, or None if valid.

    Rules:
      - 3 to 20 characters
      - Only alphanumeric characters and underscores
      - Cannot start or end with an underscore
      - No consecutive underscores
    """
    if len(username) < USERNAME_MIN_LENGTH:
        return f"Username must be at least {USERNAME_MIN_LENGTH} characters."

    if len(username) > USERNAME_MAX_LENGTH:
        return f"Username must be at most {USERNAME_MAX_LENGTH} characters."

    if not _USERNAME_PATTERN.match(username):
        if username.startswith("_") or username.endswith("_"):
            return "Username cannot start or end with an underscore."
        return "Username can only contain letters, numbers, and underscores."

    if _CONSECUTIVE_UNDERSCORES.search(username):
        return "Username cannot contain consecutive underscores."

    return None
