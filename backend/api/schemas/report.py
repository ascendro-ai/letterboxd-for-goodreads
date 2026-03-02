from __future__ import annotations

from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, Field


class IssueType(str, Enum):
    WRONG_COVER = "wrong_cover"
    WRONG_AUTHOR = "wrong_author"
    WRONG_TITLE = "wrong_title"
    WRONG_DESCRIPTION = "wrong_description"
    DUPLICATE = "duplicate"
    OTHER = "other"


class ReportStatus(str, Enum):
    OPEN = "open"
    REVIEWED = "reviewed"
    RESOLVED = "resolved"
    DISMISSED = "dismissed"


class ReportIssueRequest(BaseModel):
    issue_type: IssueType
    description: str = Field(min_length=10, max_length=1000)


class ReportIssueResponse(BaseModel):
    id: UUID
    issue_type: IssueType
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}
