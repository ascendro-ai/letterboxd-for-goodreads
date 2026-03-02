from __future__ import annotations

import uuid

import pytest
from backend.services.affiliate_service import generate_bookshop_url


class TestGenerateBookshopUrl:
    def test_isbn_link(self):
        url = generate_bookshop_url("9780143127741", "Test Book", "abc123")
        assert url == "https://bookshop.org/a/abc123/9780143127741"

    def test_isbn10_link(self):
        url = generate_bookshop_url("0143127748", "Test Book", "abc123")
        assert url == "https://bookshop.org/a/abc123/0143127748"

    def test_search_fallback_no_isbn(self):
        url = generate_bookshop_url(None, "Test Book", "abc123")
        assert url == "https://bookshop.org/a/abc123?q=Test+Book"

    def test_search_with_special_chars(self):
        url = generate_bookshop_url(None, "It's a Test & More", "abc123")
        assert "abc123" in url
        assert "q=" in url

    def test_disabled_no_affiliate_id(self):
        url = generate_bookshop_url("9780143127741", "Test Book", "")
        assert url is None

    def test_disabled_empty_affiliate_id(self):
        url = generate_bookshop_url(None, "Test Book", "")
        assert url is None

    def test_no_isbn_no_title(self):
        url = generate_bookshop_url(None, "", "abc123")
        assert url is None


@pytest.mark.asyncio
async def test_get_best_isbn_english_isbn13_preferred(db_session, test_work):
    """English ISBN-13 is preferred over other editions."""
    from backend.api.model_stubs import Edition
    from backend.services.affiliate_service import get_best_isbn_for_work

    edition = Edition(
        id=str(uuid.uuid4()),
        work_id=test_work.id,
        isbn_13="9780143127741",
        isbn_10="0143127748",
        language="en",
        publish_date="2020",
    )
    db_session.add(edition)
    await db_session.commit()

    isbn = await get_best_isbn_for_work(db_session, test_work.id)
    assert isbn == "9780143127741"


@pytest.mark.asyncio
async def test_get_best_isbn_falls_back_to_isbn10(db_session, test_work):
    """Falls back to ISBN-10 if no ISBN-13 available."""
    from backend.api.model_stubs import Edition
    from backend.services.affiliate_service import get_best_isbn_for_work

    edition = Edition(
        id=str(uuid.uuid4()),
        work_id=test_work.id,
        isbn_10="0143127748",
        language="en",
    )
    db_session.add(edition)
    await db_session.commit()

    isbn = await get_best_isbn_for_work(db_session, test_work.id)
    assert isbn == "0143127748"


@pytest.mark.asyncio
async def test_get_best_isbn_non_english_fallback(db_session, test_work):
    """Falls back to non-English edition if no English editions available."""
    from backend.api.model_stubs import Edition
    from backend.services.affiliate_service import get_best_isbn_for_work

    edition = Edition(
        id=str(uuid.uuid4()),
        work_id=test_work.id,
        isbn_13="9784101050010",
        language="ja",
    )
    db_session.add(edition)
    await db_session.commit()

    isbn = await get_best_isbn_for_work(db_session, test_work.id)
    assert isbn == "9784101050010"


@pytest.mark.asyncio
async def test_get_best_isbn_no_editions(db_session, test_work):
    """Returns None when no editions have ISBNs."""
    from backend.services.affiliate_service import get_best_isbn_for_work

    isbn = await get_best_isbn_for_work(db_session, test_work.id)
    assert isbn is None


@pytest.mark.asyncio
async def test_book_detail_includes_bookshop_url(client, test_work, db_session):
    """GET /books/{id} includes bookshop_url in response."""
    from backend.api.model_stubs import Edition

    edition = Edition(
        id=str(uuid.uuid4()),
        work_id=test_work.id,
        isbn_13="9780143127741",
        language="en",
    )
    db_session.add(edition)
    await db_session.commit()

    resp = await client.get(f"/api/v1/books/{test_work.id}")
    assert resp.status_code == 200
    data = resp.json()
    # bookshop_url should be present (may be None if no affiliate_id configured)
    assert "bookshop_url" in data
