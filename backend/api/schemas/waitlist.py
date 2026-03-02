from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, field_validator


class JoinWaitlistRequest(BaseModel):
    email: EmailStr


class WaitlistResponse(BaseModel):
    model_config = {"from_attributes": True}

    email: str
    created_at: datetime
    position: int


class InviteCodeResponse(BaseModel):
    model_config = {"from_attributes": True}

    code: str
    created_at: datetime
    is_claimed: bool
    claimed_by_username: str | None = None


class SignupWithInviteRequest(BaseModel):
    """Extended signup request that requires an invite code."""

    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    username: str = Field(min_length=3, max_length=20)
    invite_code: str = Field(min_length=1, max_length=12)

    @field_validator("invite_code")
    @classmethod
    def invite_code_not_empty(cls, v: str) -> str:
        stripped = v.strip()
        if not stripped:
            raise ValueError("Invite code is required.")
        return stripped.upper()

    @field_validator("username")
    @classmethod
    def username_stripped(cls, v: str) -> str:
        return v.strip()
