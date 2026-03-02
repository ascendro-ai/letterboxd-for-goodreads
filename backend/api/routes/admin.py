"""Minimal admin endpoints for content moderation review.

Protected by service key auth (not user JWT). For v1, admin uses these
via curl/Postman. A real admin UI can be built later.
"""

from __future__ import annotations

from datetime import datetime, timezone
from uuid import UUID

from backend.api.config import get_settings
from backend.api.deps import DB
from backend.api.model_stubs import ReviewFlag, UserBook
from fastapi import APIRouter, Header, HTTPException, Query
from sqlalchemy import select, update

router = APIRouter(prefix="/admin", tags=["admin"])


def _verify_admin(authorization: str | None) -> None:
    """Verify admin access via service key."""
    settings = get_settings()
    expected = f"Bearer {settings.supabase_service_key}"
    if not settings.supabase_service_key or not authorization or authorization != expected:
        raise HTTPException(status_code=403, detail="Admin access required")


@router.get("/flags")
async def list_pending_flags(
    db: DB,
    authorization: str | None = Header(None),
    status_filter: str = Query("pending"),
    limit: int = Query(50, ge=1, le=200),
) -> list[dict]:
    """List flagged reviews pending review."""
    _verify_admin(authorization)

    result = await db.execute(
        select(ReviewFlag)
        .where(ReviewFlag.status == status_filter)
        .order_by(ReviewFlag.created_at.desc())
        .limit(limit)
    )
    flags = result.scalars().all()

    return [
        {
            "id": str(f.id),
            "user_book_id": str(f.user_book_id),
            "reason": f.reason,
            "description": f.description,
            "status": f.status,
            "created_at": str(f.created_at),
        }
        for f in flags
    ]


@router.post("/flags/{flag_id}/resolve")
async def resolve_flag(
    flag_id: UUID,
    action: str = Query(...),
    db: DB = None,
    authorization: str | None = Header(None),
) -> dict[str, str]:
    """Resolve a flag: 'dismiss' (keep review) or 'remove' (hide review).

    Usage:
      POST /api/v1/admin/flags/{id}/resolve?action=dismiss
      POST /api/v1/admin/flags/{id}/resolve?action=remove
    """
    _verify_admin(authorization)

    if action not in ("dismiss", "remove"):
        raise HTTPException(400, "action must be 'dismiss' or 'remove'")

    result = await db.execute(select(ReviewFlag).where(ReviewFlag.id == flag_id))
    flag = result.scalar_one_or_none()
    if not flag:
        raise HTTPException(404, "Flag not found")

    if action == "remove":
        flag.status = "removed"
        flag.resolved_at = datetime.now(timezone.utc)
        await db.execute(
            update(UserBook).where(UserBook.id == flag.user_book_id).values(is_hidden=True)
        )
    else:
        flag.status = "dismissed"
        flag.resolved_at = datetime.now(timezone.utc)

    await db.flush()
    return {"status": f"Flag {action}ed"}
