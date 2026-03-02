import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import pytest


@pytest.mark.asyncio
async def test_request_export_success(client):
    """Request a data export -- happy path."""
    with patch("backend.services.export_service.asyncio.create_task"):
        resp = await client.post("/api/v1/me/export")

    assert resp.status_code == 201
    data = resp.json()
    assert data["status"] == "pending"
    assert data["file_url"] is None
    assert data["file_size_bytes"] is None
    assert "id" in data
    assert "created_at" in data


@pytest.mark.asyncio
async def test_request_export_rate_limited(client, db_session, test_user_id):
    """Second export request within 24h returns 429."""
    from backend.api.model_stubs import ExportRequest

    # Create an existing recent export
    export_req = ExportRequest(
        id=str(uuid.uuid4()),
        user_id=test_user_id,
        status="completed",
    )
    db_session.add(export_req)
    await db_session.commit()

    resp = await client.post("/api/v1/me/export")
    assert resp.status_code == 429
    data = resp.json()
    assert data["detail"]["error"]["code"] == "EXPORT_RATE_LIMITED"


@pytest.mark.asyncio
async def test_get_export_status(client, db_session, test_user_id):
    """Check export status returns most recent export."""
    from backend.api.model_stubs import ExportRequest

    export_req = ExportRequest(
        id=str(uuid.uuid4()),
        user_id=test_user_id,
        status="processing",
    )
    db_session.add(export_req)
    await db_session.commit()
    await db_session.refresh(export_req)

    resp = await client.get("/api/v1/me/export/status")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "processing"
    assert data["id"] == str(export_req.id)


@pytest.mark.asyncio
async def test_get_export_status_no_export(client):
    """Export status with no exports returns 404."""
    resp = await client.get("/api/v1/me/export/status")
    assert resp.status_code == 404
    data = resp.json()
    assert data["detail"]["error"]["code"] == "NO_EXPORT_FOUND"


@pytest.mark.asyncio
async def test_download_export_success(client, db_session, test_user_id):
    """Download a completed export -- happy path."""
    from backend.api.model_stubs import ExportRequest

    expires = datetime.now(timezone.utc) + timedelta(hours=12)
    export_req = ExportRequest(
        id=str(uuid.uuid4()),
        user_id=test_user_id,
        status="completed",
        file_url="https://r2.example.com/exports/test.json",
        file_size_bytes=12345,
        completed_at=datetime.now(timezone.utc),
        expires_at=expires,
    )
    db_session.add(export_req)
    await db_session.commit()
    await db_session.refresh(export_req)

    with patch(
        "backend.services.export_service.generate_signed_url",
        return_value="https://r2.example.com/exports/signed-url.json",
    ):
        resp = await client.get(f"/api/v1/me/export/{export_req.id}/download")

    assert resp.status_code == 200
    data = resp.json()
    assert "download_url" in data
    assert "expires_at" in data


@pytest.mark.asyncio
async def test_download_export_wrong_user(client, db_session):
    """Downloading another user's export returns 403."""
    from backend.api.model_stubs import ExportRequest

    other_user_id = str(uuid.uuid4())
    export_req = ExportRequest(
        id=str(uuid.uuid4()),
        user_id=other_user_id,
        status="completed",
        file_url="https://r2.example.com/exports/other.json",
        file_size_bytes=5000,
        completed_at=datetime.now(timezone.utc),
        expires_at=datetime.now(timezone.utc) + timedelta(hours=12),
    )
    db_session.add(export_req)
    await db_session.commit()
    await db_session.refresh(export_req)

    resp = await client.get(f"/api/v1/me/export/{export_req.id}/download")
    assert resp.status_code == 403
    data = resp.json()
    assert data["detail"]["error"]["code"] == "FORBIDDEN"


@pytest.mark.asyncio
async def test_download_export_expired(client, db_session, test_user_id):
    """Downloading an expired export returns 410."""
    from backend.api.model_stubs import ExportRequest

    export_req = ExportRequest(
        id=str(uuid.uuid4()),
        user_id=test_user_id,
        status="completed",
        file_url="https://r2.example.com/exports/expired.json",
        file_size_bytes=5000,
        completed_at=datetime.now(timezone.utc) - timedelta(hours=48),
        expires_at=datetime.now(timezone.utc) - timedelta(hours=24),
    )
    db_session.add(export_req)
    await db_session.commit()
    await db_session.refresh(export_req)

    resp = await client.get(f"/api/v1/me/export/{export_req.id}/download")
    assert resp.status_code == 410
    data = resp.json()
    assert data["detail"]["error"]["code"] == "EXPORT_EXPIRED"


@pytest.mark.asyncio
async def test_download_export_not_found(client):
    """Downloading a non-existent export returns 404."""
    fake_id = str(uuid.uuid4())
    resp = await client.get(f"/api/v1/me/export/{fake_id}/download")
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_generate_export_builds_correct_json(db_session, test_user, test_work):
    """Verify the export JSON structure is correct."""
    from backend.api.model_stubs import UserBook
    from backend.services.export_service import _serialize_user_book

    user_book = UserBook(
        id=str(uuid.uuid4()),
        user_id=test_user.id,
        work_id=test_work.id,
        status="read",
        rating=4.5,
        review_text="Wonderful book",
        has_spoilers=False,
        is_imported=False,
    )
    db_session.add(user_book)
    await db_session.commit()
    await db_session.refresh(user_book)

    serialized = _serialize_user_book(user_book, test_work)
    assert serialized["title"] == "Test Book"
    assert serialized["status"] == "read"
    assert serialized["rating"] == 4.5
    assert serialized["review_text"] == "Wonderful book"
    assert serialized["has_spoilers"] is False


@pytest.mark.asyncio
async def test_r2_upload_mock():
    """Verify R2 upload is called correctly (mocked)."""
    mock_client = MagicMock()

    with patch("backend.services.r2_storage._get_s3_client", return_value=mock_client):
        from backend.services.r2_storage import upload_to_r2

        key = upload_to_r2(b'{"test": true}', "exports/test/test.json")

        assert key == "exports/test/test.json"
        mock_client.put_object.assert_called_once()
        call_kwargs = mock_client.put_object.call_args[1]
        assert call_kwargs["Key"] == "exports/test/test.json"
        assert call_kwargs["ContentType"] == "application/json"
