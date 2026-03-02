from __future__ import annotations

from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, Field

__all__ = ["ContactHashesRequest", "DiscoverUserResponse", "DiscoverUsersResponse"]


class ContactHashesRequest(BaseModel):
    hashes: list[str] = Field(max_length=500)


class DiscoverUserResponse(BaseModel):
    id: UUID
    username: str
    display_name: str | None = None
    avatar_url: str | None = None
    taste_match_score: Decimal | None = None

    model_config = {"from_attributes": True}


class DiscoverUsersResponse(BaseModel):
    users: list[DiscoverUserResponse]
