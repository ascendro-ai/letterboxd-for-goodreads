from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel

__all__ = [
    "ExportDownloadResponse",
    "ExportStatusResponse",
]


class ExportStatusResponse(BaseModel):
    id: UUID
    status: str
    file_url: str | None = None
    file_size_bytes: int | None = None
    created_at: datetime
    completed_at: datetime | None = None
    expires_at: datetime | None = None

    model_config = {"from_attributes": True}


class ExportDownloadResponse(BaseModel):
    download_url: str
    expires_at: datetime
