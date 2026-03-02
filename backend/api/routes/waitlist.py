from __future__ import annotations

from backend.api.deps import DB, CurrentUser
from backend.api.model_stubs import Waitlist
from backend.api.schemas.waitlist import (
    InviteCodeResponse,
    JoinWaitlistRequest,
    WaitlistResponse,
)
from backend.services.invite_service import get_user_invite_codes, join_waitlist
from fastapi import APIRouter
from sqlalchemy import func, select

router = APIRouter()


@router.post("/waitlist", status_code=201, response_model=WaitlistResponse)
async def join_waitlist_endpoint(request: JoinWaitlistRequest, db: DB) -> WaitlistResponse:
    """Join the waitlist. Public endpoint, no auth required."""
    waitlist_entry = await join_waitlist(db=db, email=request.email)

    # Calculate position
    result = await db.execute(
        select(func.count())
        .select_from(Waitlist)
        .where(Waitlist.created_at <= waitlist_entry.created_at)
    )
    position = result.scalar_one()

    return WaitlistResponse(
        email=waitlist_entry.email,
        created_at=waitlist_entry.created_at,
        position=position,
    )


@router.get("/me/invite-codes", response_model=list[InviteCodeResponse])
async def list_invite_codes(db: DB, user: CurrentUser) -> list[InviteCodeResponse]:
    """List the authenticated user's invite codes."""
    codes = await get_user_invite_codes(db=db, user_id=user.id)
    return [
        InviteCodeResponse(
            code=code.code,
            created_at=code.created_at,
            is_claimed=code.claimed_by_user_id is not None,
            claimed_by_username=None,
        )
        for code in codes
    ]
