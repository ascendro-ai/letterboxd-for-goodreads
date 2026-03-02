import uuid
from unittest.mock import AsyncMock, patch

import pytest


@pytest.mark.asyncio
async def test_get_book_detail_success(client, test_work):
    resp = await client.get(f"/api/v1/books/{test_work.id}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["title"] == "Test Book"
    assert data["first_published_year"] == 2020


@pytest.mark.asyncio
async def test_get_book_detail_not_found(client):
    fake_id = uuid.uuid4()
    resp = await client.get(f"/api/v1/books/{fake_id}")
    assert resp.status_code == 404
    data = resp.json()
    assert data["detail"]["error"]["code"] == "BOOK_NOT_FOUND"


@pytest.mark.asyncio
async def test_search_books(client, test_work):
    resp = await client.get("/api/v1/books/search?q=Test")
    assert resp.status_code == 200
    data = resp.json()
    assert data["items"]
    assert data["items"][0]["title"] == "Test Book"


@pytest.mark.asyncio
async def test_search_books_empty(client):
    resp = await client.get("/api/v1/books/search?q=nonexistent_xyz")
    assert resp.status_code == 200
    data = resp.json()
    assert data["items"] == []
    assert data["has_more"] is False


@pytest.mark.asyncio
async def test_isbn_lookup_found(client, test_work, test_edition):
    resp = await client.get("/api/v1/books/isbn/9780143127741")
    assert resp.status_code == 200
    data = resp.json()
    assert data["title"] == "Test Book"


@pytest.mark.asyncio
async def test_isbn_lookup_not_found(client):
    """ISBN not in DB and mock Open Library returning 404."""
    mock_resp = AsyncMock()
    mock_resp.status_code = 404

    with patch("backend.services.book_service.httpx.AsyncClient") as mock_client:
        mock_instance = AsyncMock()
        mock_instance.get.return_value = mock_resp
        mock_instance.__aenter__ = AsyncMock(return_value=mock_instance)
        mock_instance.__aexit__ = AsyncMock(return_value=False)
        mock_client.return_value = mock_instance

        resp = await client.get("/api/v1/books/isbn/0000000000000")
        assert resp.status_code == 404
