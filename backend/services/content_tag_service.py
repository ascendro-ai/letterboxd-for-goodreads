"""Service for community-voted content tags on works.

Users can vote to add content warnings or mood tags to books. Once a tag
reaches the vote threshold, it becomes "confirmed" and is shown prominently.
Each user can only vote once per tag per book.
"""

from __future__ import annotations

from uuid import UUID

from backend.api.errors import AppError
from backend.api.model_stubs import WorkContentTag, WorkContentTagVote
from backend.api.schemas.content_tags import ContentTagResponse, VoteTagRequest
from backend.services.content_tags import ALL_TAGS, VOTE_THRESHOLD, get_tag_type, is_valid_tag
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession


async def get_work_tags(
    db: AsyncSession,
    work_id: UUID,
) -> list[ContentTagResponse]:
    """Get all content tags for a work, ordered by vote count."""
    result = await db.execute(
        select(WorkContentTag)
        .where(WorkContentTag.work_id == work_id)
        .order_by(WorkContentTag.vote_count.desc())
    )
    tags = result.scalars().all()

    return [
        ContentTagResponse(
            id=tag.id,
            tag_name=tag.tag_name,
            tag_type=tag.tag_type,
            vote_count=tag.vote_count,
            is_confirmed=tag.is_confirmed,
            display_name=tag.tag_name.replace("_", " ").title(),
        )
        for tag in tags
    ]


async def vote_tag(
    db: AsyncSession,
    user_id: UUID,
    work_id: UUID,
    request: VoteTagRequest,
) -> ContentTagResponse:
    """Vote for a content tag on a work. Creates the tag if it doesn't exist."""
    if not is_valid_tag(request.tag_name):
        raise AppError(
            status_code=422,
            code="INVALID_TAG",
            message=f"'{request.tag_name}' is not a valid tag. Use GET /books/tags/available for the list.",
        )

    tag_type = get_tag_type(request.tag_name)

    # Find or create the tag
    result = await db.execute(
        select(WorkContentTag).where(
            WorkContentTag.work_id == work_id,
            WorkContentTag.tag_name == request.tag_name,
        )
    )
    tag = result.scalar_one_or_none()

    if tag is None:
        tag = WorkContentTag(
            work_id=work_id,
            tag_name=request.tag_name,
            tag_type=tag_type,
            vote_count=1,
            is_confirmed=False,
        )
        db.add(tag)
        await db.flush()

        vote = WorkContentTagVote(
            user_id=user_id,
            work_content_tag_id=tag.id,
        )
        db.add(vote)
        await db.flush()
    else:
        # Check if user already voted
        existing_vote = await db.execute(
            select(WorkContentTagVote).where(
                WorkContentTagVote.user_id == user_id,
                WorkContentTagVote.work_content_tag_id == tag.id,
            )
        )
        if existing_vote.scalar_one_or_none() is not None:
            raise AppError(
                status_code=409,
                code="ALREADY_VOTED",
                message="You have already voted for this tag on this book.",
            )

        vote = WorkContentTagVote(
            user_id=user_id,
            work_content_tag_id=tag.id,
        )
        db.add(vote)
        tag.vote_count += 1

        if tag.vote_count >= VOTE_THRESHOLD and not tag.is_confirmed:
            tag.is_confirmed = True

        await db.flush()

    return ContentTagResponse(
        id=tag.id,
        tag_name=tag.tag_name,
        tag_type=tag.tag_type,
        vote_count=tag.vote_count,
        is_confirmed=tag.is_confirmed,
        display_name=tag.tag_name.replace("_", " ").title(),
    )


async def remove_vote(
    db: AsyncSession,
    user_id: UUID,
    work_id: UUID,
    tag_name: str,
) -> None:
    """Remove a user's vote from a content tag."""
    result = await db.execute(
        select(WorkContentTag).where(
            WorkContentTag.work_id == work_id,
            WorkContentTag.tag_name == tag_name,
        )
    )
    tag = result.scalar_one_or_none()
    if tag is None:
        raise AppError(404, "TAG_NOT_FOUND", "Tag not found on this book.")

    vote_result = await db.execute(
        select(WorkContentTagVote).where(
            WorkContentTagVote.user_id == user_id,
            WorkContentTagVote.work_content_tag_id == tag.id,
        )
    )
    vote = vote_result.scalar_one_or_none()
    if vote is None:
        raise AppError(404, "VOTE_NOT_FOUND", "You haven't voted for this tag.")

    await db.delete(vote)
    tag.vote_count -= 1

    if tag.vote_count < VOTE_THRESHOLD:
        tag.is_confirmed = False

    if tag.vote_count <= 0:
        await db.delete(tag)

    await db.flush()


async def get_available_tags() -> dict[str, list[str]]:
    """Return the full list of available tags, grouped by type."""
    content_warnings = [k for k, v in ALL_TAGS.items() if v == "content_warning"]
    moods = [k for k, v in ALL_TAGS.items() if v == "mood"]
    return {
        "content_warnings": sorted(content_warnings),
        "moods": sorted(moods),
    }
