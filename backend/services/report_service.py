from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import UUID

from backend.api.errors import duplicate_report, report_rate_limited, work_not_found
from backend.api.model_stubs import MetadataReport, Work
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

DAILY_REPORT_LIMIT = 10


async def get_user_report_count_today(db: AsyncSession, user_id: UUID) -> int:
    """Count reports submitted by a user in the last 24 hours."""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
    result = await db.execute(
        select(func.count())
        .select_from(MetadataReport)
        .where(
            MetadataReport.reporter_user_id == user_id,
            MetadataReport.created_at >= cutoff,
        )
    )
    return result.scalar() or 0


async def report_issue(
    db: AsyncSession,
    user_id: UUID,
    work_id: UUID,
    issue_type: str,
    description: str,
) -> MetadataReport:
    """Submit a metadata issue report for a work.

    Validates:
      - Work exists (404 if not)
      - No existing open report from same user for same work+issue_type (409 if exists)
      - User has not exceeded daily report limit (429 if exceeded)
    """
    # Verify work exists
    work_result = await db.execute(select(Work.id).where(Work.id == work_id))
    if work_result.scalar_one_or_none() is None:
        raise work_not_found()

    # Check for existing open report from same user for same work + issue_type
    existing_result = await db.execute(
        select(MetadataReport).where(
            MetadataReport.reporter_user_id == user_id,
            MetadataReport.work_id == work_id,
            MetadataReport.issue_type == issue_type,
            MetadataReport.status == "OPEN",
        )
    )
    if existing_result.scalar_one_or_none() is not None:
        raise duplicate_report()

    # Check daily rate limit
    today_count = await get_user_report_count_today(db, user_id)
    if today_count >= DAILY_REPORT_LIMIT:
        raise report_rate_limited()

    # Create the report
    report = MetadataReport(
        reporter_user_id=user_id,
        work_id=work_id,
        issue_type=issue_type,
        description=description,
        status="OPEN",
    )
    db.add(report)
    await db.flush()
    await db.refresh(report)

    return report
