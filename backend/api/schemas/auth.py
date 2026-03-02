from pydantic import BaseModel, EmailStr, Field

__all__ = [
    "AuthResponse",
    "DeleteAccountRequest",
    "LoginRequest",
    "OAuthTokenRequest",
    "RefreshRequest",
    "SignupRequest",
]


class SignupRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    username: str = Field(min_length=3, max_length=30, pattern=r"^[a-zA-Z0-9_]+$")


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class OAuthTokenRequest(BaseModel):
    id_token: str


class RefreshRequest(BaseModel):
    refresh_token: str


class AuthResponse(BaseModel):
    access_token: str
    refresh_token: str
    user_id: str
    username: str


class DeleteAccountRequest(BaseModel):
    """Request body for account deletion. Requires explicit confirmation."""

    confirm: bool = Field(
        ...,
        description="Must be true to confirm account deletion.",
    )
