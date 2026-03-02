# LIMITATION: Auth routes proxy directly to Supabase Auth REST API via httpx.
# These are NOT covered by integration tests (Supabase calls would need to be mocked
# or a real Supabase project configured). Verify against a live Supabase instance
# before shipping. Error handling from Supabase is minimal — production should map
# Supabase error codes to user-friendly messages.

import httpx
from backend.api.config import get_settings
from backend.api.deps import DB, CurrentUser
from backend.api.errors import AppError, duplicate_username
from backend.api.model_stubs import InviteCode, User
from backend.api.schemas.auth import (
    AuthResponse,
    DeleteAccountRequest,
    LoginRequest,
    OAuthTokenRequest,
    RefreshRequest,
)
from backend.api.schemas.waitlist import SignupWithInviteRequest
from backend.services.invite_service import generate_codes_for_user, validate_and_claim_code
from backend.services.observability import Events, track_event
from backend.services.reserved_usernames import is_username_reserved, validate_username_format
from backend.services.user_service import soft_delete_account
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

router = APIRouter()


@router.post("/signup", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def signup(request: SignupWithInviteRequest, db: DB) -> AuthResponse:
    """Create a new account via email+password with invite code. Also creates User row."""
    settings = get_settings()

    # Username format validation
    format_error = validate_username_format(request.username)
    if format_error is not None:
        raise AppError(status_code=422, code="USERNAME_INVALID", message=format_error)

    if is_username_reserved(request.username):
        raise AppError(
            status_code=422, code="USERNAME_RESERVED", message="This username is not available."
        )

    # Check username uniqueness
    existing = await db.execute(select(User).where(User.username == request.username))
    if existing.scalar_one_or_none() is not None:
        raise duplicate_username()

    # Pre-validate invite code exists and is available
    code_result = await db.execute(select(InviteCode).where(InviteCode.code == request.invite_code))
    invite_code = code_result.scalar_one_or_none()

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

    if invite_code.expires_at is not None:
        from datetime import datetime, timezone

        if invite_code.expires_at < datetime.now(timezone.utc):
            raise AppError(
                status_code=422,
                code="INVITE_CODE_EXPIRED",
                message="This invite code has expired.",
            )

    # Create user in Supabase Auth
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{settings.supabase_url}/auth/v1/signup",
            json={"email": request.email, "password": request.password},
            headers={
                "apikey": settings.supabase_service_key,
                "Content-Type": "application/json",
            },
        )
        if resp.status_code != 200:
            raise HTTPException(status_code=resp.status_code, detail=resp.json())

        data = resp.json()

    # Create local user row
    user = User(
        id=data["user"]["id"],
        username=request.username,
    )
    db.add(user)
    await db.flush()

    # Claim the invite code
    await validate_and_claim_code(db=db, code=request.invite_code, user_id=user.id)

    # Generate 5 invite codes for the new user
    await generate_codes_for_user(db=db, user_id=user.id, count=5)

    return AuthResponse(
        access_token=data["access_token"],
        refresh_token=data["refresh_token"],
        user_id=str(user.id),
        username=user.username,
    )


@router.post("/login", response_model=AuthResponse)
async def login(request: LoginRequest, db: DB) -> AuthResponse:
    """Login with email+password via Supabase Auth."""
    settings = get_settings()

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{settings.supabase_url}/auth/v1/token?grant_type=password",
            json={"email": request.email, "password": request.password},
            headers={
                "apikey": settings.supabase_service_key,
                "Content-Type": "application/json",
            },
        )
        if resp.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials"
            )

        data = resp.json()

    # Look up username
    result = await db.execute(select(User).where(User.id == data["user"]["id"]))
    user = result.scalar_one_or_none()
    username = user.username if user else ""

    return AuthResponse(
        access_token=data["access_token"],
        refresh_token=data["refresh_token"],
        user_id=str(data["user"]["id"]),
        username=username,
    )


@router.post("/apple", response_model=AuthResponse)
async def apple_signin(request: OAuthTokenRequest, db: DB) -> AuthResponse:
    """Exchange Apple ID token for Supabase session."""
    return await _oauth_exchange(request.id_token, "apple", db)


@router.post("/google", response_model=AuthResponse)
async def google_signin(request: OAuthTokenRequest, db: DB) -> AuthResponse:
    """Exchange Google ID token for Supabase session."""
    return await _oauth_exchange(request.id_token, "google", db)


async def _oauth_exchange(id_token: str, provider: str, db: DB) -> AuthResponse:
    """Shared logic for OAuth token exchange with Supabase."""
    settings = get_settings()

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{settings.supabase_url}/auth/v1/token?grant_type=id_token",
            json={"provider": provider, "id_token": id_token},
            headers={
                "apikey": settings.supabase_service_key,
                "Content-Type": "application/json",
            },
        )
        if resp.status_code != 200:
            raise HTTPException(status_code=resp.status_code, detail=resp.json())

        data = resp.json()

    # Check if user row exists, create if not
    user_id = data["user"]["id"]
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if user is None:
        email = data["user"].get("email", "")
        username = email.split("@")[0] if email else f"user_{user_id[:8]}"
        user = User(id=user_id, username=username)
        db.add(user)
        await db.flush()

    return AuthResponse(
        access_token=data["access_token"],
        refresh_token=data["refresh_token"],
        user_id=str(user.id),
        username=user.username,
    )


@router.post("/refresh", response_model=AuthResponse)
async def refresh(request: RefreshRequest) -> AuthResponse:
    """Refresh a Supabase JWT."""
    settings = get_settings()

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{settings.supabase_url}/auth/v1/token?grant_type=refresh_token",
            json={"refresh_token": request.refresh_token},
            headers={
                "apikey": settings.supabase_service_key,
                "Content-Type": "application/json",
            },
        )
        if resp.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token"
            )

        data = resp.json()

    return AuthResponse(
        access_token=data["access_token"],
        refresh_token=data["refresh_token"],
        user_id=str(data["user"]["id"]),
        username="",
    )


@router.delete("/account", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    request: DeleteAccountRequest,
    db: DB,
    current_user: CurrentUser,
) -> None:
    """GDPR-compliant account deletion with full data anonymization.

    Requires {"confirm": true} in the request body. Anonymizes all personal
    data, removes social connections, and preserves reviews under "Deleted User".
    Returns 204 No Content on success.
    """
    if not request.confirm:
        raise AppError(
            status_code=422,
            code="CONFIRMATION_REQUIRED",
            message="You must set 'confirm' to true to delete your account.",
        )

    await soft_delete_account(db, current_user.id)
    await db.commit()

    track_event(
        user_id=str(current_user.id),
        event_name=Events.USER_DELETED_ACCOUNT,
        properties={"username": current_user.username},
    )
