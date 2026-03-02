# LIMITATION: Auth routes proxy directly to Supabase Auth REST API via httpx.
# These are NOT covered by integration tests (Supabase calls would need to be mocked
# or a real Supabase project configured). Verify against a live Supabase instance
# before shipping. Error handling from Supabase is minimal — production should map
# Supabase error codes to user-friendly messages.

import httpx
from backend.api.config import get_settings
from backend.api.deps import DB, CurrentUser
from backend.api.errors import duplicate_username
from backend.api.model_stubs import User
from backend.api.schemas.auth import (
    AuthResponse,
    LoginRequest,
    OAuthTokenRequest,
    RefreshRequest,
    SignupRequest,
)
from fastapi import APIRouter, HTTPException, status

router = APIRouter()


@router.post("/signup", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def signup(request: SignupRequest, db: DB) -> AuthResponse:
    """Create a new account via email+password. Also creates the User row in our DB."""
    settings = get_settings()

    # Check username uniqueness
    from sqlalchemy import select

    existing = await db.execute(select(User).where(User.username == request.username))
    if existing.scalar_one_or_none() is not None:
        raise duplicate_username()

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
    from sqlalchemy import select

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
    from sqlalchemy import select

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


@router.delete("/account", status_code=status.HTTP_200_OK)
async def delete_account(db: DB, current_user: CurrentUser) -> dict[str, str]:
    """Soft delete: anonymize user data, mark as deleted."""
    current_user.is_deleted = True
    current_user.username = f"deleted_{str(current_user.id)[:8]}"
    current_user.display_name = None
    current_user.bio = None
    current_user.avatar_url = None
    current_user.favorite_books = None
    await db.flush()
    return {"message": "Account deleted"}
