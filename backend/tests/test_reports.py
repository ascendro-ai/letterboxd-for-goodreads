from __future__ import annotations

import uuid

import pytest
from backend.api.model_stubs import MetadataReport, Work


@pytest.mark.asyncio
async def test_report_issue_success(client, test_work):
    """Happy path: submit a metadata report and get back 201."""
    resp = await client.post(
        f"/api/v1/books/{test_work.id}/report",
        json={
            "issue_type": "wrong_cover",
            "description": "The cover image shows the wrong edition of the book.",
        },
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["issue_type"] == "wrong_cover"
    assert data["status"] == "OPEN"
    assert "id" in data
    assert "created_at" in data


@pytest.mark.asyncio
async def test_report_issue_duplicate_returns_409(client, test_work):
    """Submitting the same issue type for the same work twice returns 409."""
    payload = {
        "issue_type": "wrong_author",
        "description": "The listed author is incorrect, should be Jane Doe.",
    }
    resp1 = await client.post(f"/api/v1/books/{test_work.id}/report", json=payload)
    assert resp1.status_code == 201

    resp2 = await client.post(f"/api/v1/books/{test_work.id}/report", json=payload)
    assert resp2.status_code == 409
    assert resp2.json()["detail"]["error"]["code"] == "DUPLICATE_REPORT"


@pytest.mark.asyncio
async def test_report_issue_nonexistent_work_returns_404(client):
    """Reporting on a work that does not exist returns 404."""
    fake_id = uuid.uuid4()
    resp = await client.post(
        f"/api/v1/books/{fake_id}/report",
        json={
            "issue_type": "wrong_title",
            "description": "This title is completely wrong, please fix it.",
        },
    )
    assert resp.status_code == 404
    assert resp.json()["detail"]["error"]["code"] == "WORK_NOT_FOUND"


@pytest.mark.asyncio
async def test_report_issue_rate_limit(client, db_session, test_work, test_user_id):
    """Submitting more than 10 reports in 24 hours returns 429."""
    # Create 10 reports directly in the DB to hit the limit
    for i in range(10):
        report = MetadataReport(
            id=str(uuid.uuid4()),
            reporter_user_id=str(test_user_id),
            work_id=str(test_work.id),
            issue_type="other",
            description=f"Rate limit test report number {i + 1} for testing purposes.",
            status="OPEN",
        )
        db_session.add(report)
    await db_session.commit()

    # The 11th report via API should be rate limited
    resp = await client.post(
        f"/api/v1/books/{test_work.id}/report",
        json={
            "issue_type": "wrong_cover",
            "description": "This should be rate limited because we hit the daily cap.",
        },
    )
    assert resp.status_code == 429
    assert resp.json()["detail"]["error"]["code"] == "REPORT_RATE_LIMITED"


@pytest.mark.asyncio
async def test_report_issue_different_types_allowed(client, test_work):
    """Different issue types for the same work are allowed."""
    resp1 = await client.post(
        f"/api/v1/books/{test_work.id}/report",
        json={
            "issue_type": "wrong_cover",
            "description": "The cover image is from a completely different book.",
        },
    )
    assert resp1.status_code == 201

    resp2 = await client.post(
        f"/api/v1/books/{test_work.id}/report",
        json={
            "issue_type": "wrong_author",
            "description": "The author listed here is not the actual author.",
        },
    )
    assert resp2.status_code == 201

    assert resp1.json()["id"] != resp2.json()["id"]


@pytest.mark.asyncio
async def test_report_issue_description_too_short(client, test_work):
    """Description shorter than 10 characters is rejected by Pydantic validation."""
    resp = await client.post(
        f"/api/v1/books/{test_work.id}/report",
        json={
            "issue_type": "wrong_cover",
            "description": "Short",
        },
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_report_issue_description_too_long(client, test_work):
    """Description longer than 1000 characters is rejected by Pydantic validation."""
    resp = await client.post(
        f"/api/v1/books/{test_work.id}/report",
        json={
            "issue_type": "wrong_cover",
            "description": "x" * 1001,
        },
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_report_issue_all_valid_types(client, db_session, test_work):
    """Each valid issue type can be submitted successfully."""
    valid_types = [
        "wrong_cover",
        "wrong_author",
        "wrong_title",
        "wrong_description",
        "duplicate",
        "other",
    ]
    for issue_type in valid_types:
        # Create a fresh work for each to avoid duplicate constraints
        work = Work(
            id=str(uuid.uuid4()),
            title=f"Test Book for {issue_type}",
            ratings_count=0,
        )
        db_session.add(work)
        await db_session.commit()
        await db_session.refresh(work)

        resp = await client.post(
            f"/api/v1/books/{work.id}/report",
            json={
                "issue_type": issue_type,
                "description": f"Testing report submission for issue type: {issue_type}.",
            },
        )
        assert resp.status_code == 201, f"Failed for issue_type={issue_type}: {resp.text}"
        assert resp.json()["issue_type"] == issue_type
