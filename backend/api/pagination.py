"""Cursor-keyset pagination for feed and list endpoints.

Uses (created_at, id) as a compound cursor to avoid offset-based pagination
problems (inconsistent pages when new rows are inserted). The cursor is
base64-encoded so clients treat it as an opaque string.
"""

from __future__ import annotations

import base64
import json
from datetime import datetime
from typing import TYPE_CHECKING
from uuid import UUID

if TYPE_CHECKING:
    from sqlalchemy import Select


def encode_cursor(created_at: datetime, id: UUID) -> str:
    """Encode a (created_at, id) pair into a base64 cursor string."""
    data = {"t": created_at.isoformat(), "i": str(id)}
    return base64.urlsafe_b64encode(json.dumps(data).encode()).decode().rstrip("=")


def decode_cursor(cursor: str | None) -> tuple[datetime, UUID] | None:
    """Decode a cursor string back to (created_at, id). Returns None if cursor is None/empty."""
    if not cursor:
        return None
    padding = 4 - len(cursor) % 4
    if padding != 4:
        cursor += "=" * padding
    data = json.loads(base64.urlsafe_b64decode(cursor))
    return (datetime.fromisoformat(data["t"]), UUID(data["i"]))


def apply_cursor_filter(query: Select, model: type, cursor: str | None) -> Select:
    """Apply cursor-based pagination WHERE clause to a SQLAlchemy Select.

    Requires the model to have `created_at` and `id` columns.
    Results should be ordered by (created_at DESC, id DESC).
    """
    decoded = decode_cursor(cursor)
    if decoded is None:
        return query
    ts, id_ = decoded
    # Tie-break on id when created_at matches -- guarantees stable ordering
    # even with identical timestamps
    return query.where((model.created_at < ts) | ((model.created_at == ts) & (model.id < id_)))
