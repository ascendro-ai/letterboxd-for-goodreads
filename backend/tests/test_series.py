"""Tests for book series endpoints and service."""

import uuid

import pytest

from backend.api.model_stubs import Series, SeriesWork, UserBook


@pytest.fixture
async def test_series(db_session):
    s = Series(
        id=str(uuid.uuid4()),
        name="The Lord of the Rings",
        description="Epic high-fantasy trilogy by J.R.R. Tolkien.",
        total_books=3,
        is_complete=True,
    )
    db_session.add(s)
    await db_session.commit()
    await db_session.refresh(s)
    return s


@pytest.fixture
async def series_with_works(db_session, test_series, test_work):
    sw = SeriesWork(
        id=str(uuid.uuid4()),
        series_id=test_series.id,
        work_id=test_work.id,
        position=1.0,
        is_main_entry=True,
    )
    db_session.add(sw)
    await db_session.commit()
    return test_series


class TestGetSeries:
    async def test_get_series(self, client, series_with_works):
        resp = await client.get(f"/api/v1/series/{series_with_works.id}")
        assert resp.status_code == 200
        data = resp.json()
        assert data["name"] == "The Lord of the Rings"
        assert data["is_complete"] is True
        assert data["total_books"] == 3
        assert len(data["works"]) == 1

    async def test_get_series_not_found(self, client):
        fake_id = str(uuid.uuid4())
        resp = await client.get(f"/api/v1/series/{fake_id}")
        assert resp.status_code == 404


class TestSeriesProgress:
    async def test_progress_no_books_read(self, client, series_with_works):
        resp = await client.get(f"/api/v1/series/{series_with_works.id}/progress")
        assert resp.status_code == 200
        data = resp.json()
        assert data["total_main_entries"] == 1
        assert data["read_count"] == 0
        assert data["reading_count"] == 0
        assert data["progress_percent"] == 0.0

    async def test_progress_with_read_book(
        self, client, db_session, series_with_works, test_user, test_work
    ):
        ub = UserBook(
            id=str(uuid.uuid4()),
            user_id=test_user.id,
            work_id=test_work.id,
            status="read",
        )
        db_session.add(ub)
        await db_session.commit()

        resp = await client.get(f"/api/v1/series/{series_with_works.id}/progress")
        assert resp.status_code == 200
        data = resp.json()
        assert data["read_count"] == 1
        assert data["progress_percent"] == 100.0

    async def test_progress_not_found(self, client):
        fake_id = str(uuid.uuid4())
        resp = await client.get(f"/api/v1/series/{fake_id}/progress")
        assert resp.status_code == 404


class TestBookSeries:
    async def test_get_book_series(self, client, series_with_works, test_work):
        resp = await client.get(f"/api/v1/books/{test_work.id}/series")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) >= 1
        assert data[0]["name"] == "The Lord of the Rings"

    async def test_get_book_series_empty(self, client):
        fake_id = str(uuid.uuid4())
        resp = await client.get(f"/api/v1/books/{fake_id}/series")
        assert resp.status_code == 200
        assert resp.json() == []
