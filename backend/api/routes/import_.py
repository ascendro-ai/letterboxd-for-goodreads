# LIMITATION: Import processing uses asyncio.create_task() which runs in the
# same process as the web server. This means:
#   - Tasks are lost if the server restarts mid-import
#   - No retry logic on failure
#   - No horizontal scaling (task runs on the node that received the request)
# For production, replace with a proper task queue (ARQ, Celery, or a
# Railway cron job) that persists tasks and supports retries.

import asyncio

from backend.api.deps import DB, CurrentUser
from backend.api.schemas.import_ import ImportStatusResponse
from backend.services import import_service
from fastapi import APIRouter, UploadFile, status

router = APIRouter()


@router.post("/goodreads", response_model=ImportStatusResponse, status_code=status.HTTP_201_CREATED)
async def import_goodreads(
    file: UploadFile,
    db: DB,
    current_user: CurrentUser,
) -> ImportStatusResponse:
    """Upload a Goodreads CSV export to import your library."""
    content = await file.read()
    job = await import_service.start_import(db, current_user.id, content, "goodreads")
    _task = asyncio.create_task(  # noqa: RUF006
        import_service.process_goodreads_csv(job.id, current_user.id, content)
    )
    return ImportStatusResponse.model_validate(job)


@router.post(
    "/storygraph", response_model=ImportStatusResponse, status_code=status.HTTP_201_CREATED
)
async def import_storygraph(
    file: UploadFile,
    db: DB,
    current_user: CurrentUser,
) -> ImportStatusResponse:
    """Upload a StoryGraph CSV export to import your library."""
    content = await file.read()
    job = await import_service.start_import(db, current_user.id, content, "storygraph")
    _task = asyncio.create_task(  # noqa: RUF006
        import_service.process_storygraph_csv(job.id, current_user.id, content)
    )
    return ImportStatusResponse.model_validate(job)


@router.get("/status", response_model=ImportStatusResponse)
async def get_import_status(
    db: DB,
    current_user: CurrentUser,
) -> ImportStatusResponse:
    """Check the status of your most recent import."""
    return await import_service.get_import_status(db, current_user.id)
