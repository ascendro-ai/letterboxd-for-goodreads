from __future__ import annotations

import re
import unicodedata


def slugify(text: str) -> str:
    """Convert text to a URL-safe slug."""
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    text = re.sub(r"[^\w\s-]", "", text.lower())
    return re.sub(r"[-\s]+", "-", text).strip("-")


def build_bookshop_url(title: str, affiliate_id: str) -> str | None:
    """Build a Bookshop.org affiliate search URL for a book title."""
    if not affiliate_id:
        return None
    query = title.replace(" ", "+")
    return f"https://bookshop.org/search?keywords={query}&affiliate={affiliate_id}"
