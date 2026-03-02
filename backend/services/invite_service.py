from __future__ import annotations

import secrets
import string
import uuid
from datetime import datetime, timezone

from backend.api.errors import AppError
from backend.api.model_stubs import InviteCode, Waitlist
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

# 8-character alphanumeric uppercase code
_CODE_ALPHABET = string.ascii_uppercase + string.digits
_CODE_LENGTH = 8
_CODES_PER_USER = 5


def generate_code() -> str:
    """Generate an 8-character uppercase alphanumeric invite code."""
    return "".join(secrets.choice(_CODE_ALPHABET) for _ in range(_CODE_LENGTH))


async def generate_codes_for_user(
    db: AsyncSession,
    user_id: uuid.UUID,
    count: int = _CODES_PER_USER,
) -> list[InviteCode]:
    """Generate a batch of invite codes owned by a user."""
    codes: list[InviteCode] = []
    attempts = 0
    max_attempts = count * 3

    while len(codes) < count and attempts < max_attempts:
        attempts += 1
        code_str = generate_code()

        # Check uniqueness
        result = await db.execute(select(InviteCode).where(InviteCode.code == code_str))
        if result.scalar_one_or_none() is not None:
            continue

        invite_code = InviteCode(
            code=code_str,
            created_by_user_id=user_id,
        )
        db.add(invite_code)
        codes.append(invite_code)

    await db.flush()
    return codes


async def validate_and_claim_code(
    db: AsyncSession,
    code: str,
    user_id: uuid.UUID,
) -> InviteCode:
    """Validate an invite code and mark it as claimed."""
    result = await db.execute(select(InviteCode).where(InviteCode.code == code.strip().upper()))
    invite_code = result.scalar_one_or_none()

    if invite_code is None:
        raise AppError(
            status_code=422,
            code="INVITE_CODE_INVALID",
            message="This invite code is not valid.",
        )

    if invite_code.claimed_by_user_id is not None:
        raise AppError(
            status_code=422,
            code="INVITE_CODE_CLAIMED",
            message="This invite code has already been used.",
        )

    if invite_code.expires_at is not None and invite_code.expires_at < datetime.now(timezone.utc):
        raise AppError(
            status_code=422,
            code="INVITE_CODE_EXPIRED",
            message="This invite code has expired.",
        )

    invite_code.claimed_by_user_id = user_id
    invite_code.claimed_at = datetime.now(timezone.utc)
    await db.flush()

    return invite_code


async def join_waitlist(db: AsyncSession, email: str) -> Waitlist:
    """Add an email to the waitlist."""
    normalized_email = email.strip().lower()

    result = await db.execute(select(Waitlist).where(Waitlist.email == normalized_email))
    existing = result.scalar_one_or_none()

    if existing is not None:
        raise AppError(
            status_code=409,
            code="WAITLIST_DUPLICATE",
            message="This email is already on the waitlist.",
        )

    entry = Waitlist(email=normalized_email)
    db.add(entry)
    await db.flush()
    await db.refresh(entry)

    return entry


async def get_user_invite_codes(
    db: AsyncSession,
    user_id: uuid.UUID,
) -> list[InviteCode]:
    """Get all invite codes created by a user."""
    result = await db.execute(
        select(InviteCode)
        .where(InviteCode.created_by_user_id == user_id)
        .order_by(InviteCode.created_at)
    )
    return list(result.scalars().all())
