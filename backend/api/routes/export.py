from __future__ import annotations

from uuid import UUID

from backend.api.deps import DB, CurrentUser
from backend.api.schemas.export import ExportDownloadResponse, ExportStatusResponse
from backend.services import export_service
from fastapi import APIRouter, status

router = APIRouter()


@router.post(
    "/me/export",
    response_model=ExportStatusResponse,
    status_code=status.HTTP_201_CREATED,
)
async def request_export(
    db: DB,
    current_user: CurrentUser,
) -> ExportStatusResponse:
    """Request a data export. Rate limited to 1 per 24 hours."""
    return await export_service.request_export(db, current_user.id)


@router.get("/me/export/status", response_model=ExportStatusResponse)
async def get_export_status(
    db: DB,
    current_user: CurrentUser,
) -> ExportStatusResponse:
    """Check the status of your most recent data export."""
    return await export_service.get_export_status(db, current_user.id)


@router.get("/me/export/{export_id}/download", response_model=ExportDownloadResponse)
async def download_export(
    export_id: UUID,
    db: DB,
    current_user: CurrentUser,
) -> ExportDownloadResponse:
    """Get a signed download URL for a completed export."""
    from datetime import datetime, timedelta, timezone

    download_url = await export_service.get_download_url(db, current_user.id, export_id)
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=86400)
    return ExportDownloadResponse(download_url=download_url, expires_at=expires_at)
