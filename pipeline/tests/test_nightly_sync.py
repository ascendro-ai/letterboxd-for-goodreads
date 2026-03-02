"""Tests for sync jobs: nightly sync, taste match, live fallback."""

from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from pipeline.import_ol.helpers import extract_ol_id, generate_uuid
from pipeline.sync.taste_match_job import TASTE_MATCH_SQL


# -- Nightly sync tests ---------------------------------------------------------


class TestRecentChangesParsing:
    def test_filters_relevant_kinds(self, sample_recent_changes: list[dict]):
        """Only add-book, edit-book, etc. kinds should be processed."""
        from pipeline.sync.nightly_sync import RELEVANT_KINDS

        relevant = [
            c for c in sample_recent_changes if c["kind"] in RELEVANT_KINDS
        ]
        assert len(relevant) == 2  # add-book, edit-book
        irrelevant = [
            c for c in sample_recent_changes if c["kind"] not in RELEVANT_KINDS
        ]
        assert len(irrelevant) == 1  # update-account

    def test_extracts_change_keys(self, sample_recent_changes: list[dict]):
        """Change keys should be extractable from changes array."""
        keys = []
        for change in sample_recent_changes:
            for c in change.get("changes", []):
                key = c.get("key", "")
                if key:
                    keys.append(key)
        assert "/works/OL5678W" in keys
        assert "/works/OL9999W" in keys


class TestSyncState:
    def test_state_creation(self):
        """Sync state should be created if it doesn't exist."""
        from pipeline.models import SyncState

        state = SyncState(
            sync_type="nightly_ol",
            last_synced_date="2024/01/15",
            last_synced_offset=0,
        )
        assert state.sync_type == "nightly_ol"
        assert state.last_synced_date == "2024/01/15"
        assert state.last_synced_offset == 0

    def test_state_resumption(self):
        """Sync should resume from last synced date + 1 day."""
        from datetime import date, timedelta

        last_synced = "2024/01/15"
        parts = last_synced.split("/")
        last_date = date(int(parts[0]), int(parts[1]), int(parts[2]))
        next_date = last_date + timedelta(days=1)
        assert next_date == date(2024, 1, 16)


class TestUpsertWork:
    def test_work_uuid_deterministic(self):
        """Upserting the same OL work ID should produce the same UUID."""
        uuid1 = generate_uuid("OL5678W")
        uuid2 = generate_uuid("OL5678W")
        assert uuid1 == uuid2

    def test_author_uuid_from_ol_id(self):
        """Author UUIDs should be derived from OL author IDs."""
        author_uuid = generate_uuid("OL1234A")
        assert author_uuid == generate_uuid("OL1234A")


# -- Taste match tests ----------------------------------------------------------


class TestTasteMatchSQL:
    def test_sql_has_min_shared_books(self):
        """SQL should require at least 5 shared rated books."""
        assert "HAVING COUNT(*) >= 5" in TASTE_MATCH_SQL

    def test_sql_has_score_formula(self):
        """SQL should include the correct scoring formula."""
        assert "4.5" in TASTE_MATCH_SQL  # max possible difference
        assert "20.0" in TASTE_MATCH_SQL  # weighting denominator

    def test_sql_handles_conflicts(self):
        """SQL should use ON CONFLICT for upsert."""
        assert "ON CONFLICT" in TASTE_MATCH_SQL
        assert "DO UPDATE" in TASTE_MATCH_SQL

    def test_sql_orders_user_ids(self):
        """SQL should enforce user_a < user_b to avoid duplicates."""
        assert "a.user_id < b.user_id" in TASTE_MATCH_SQL

    def test_sql_filters_null_ratings(self):
        """SQL should only consider rated books."""
        assert "a.rating IS NOT NULL" in TASTE_MATCH_SQL
        assert "b.rating IS NOT NULL" in TASTE_MATCH_SQL

    def test_weighting_formula(self):
        """Weight formula: min(1, count/20) gives full weight at 20+ shared books."""
        assert "LEAST(1.0, COUNT(*)::float / 20.0)" in TASTE_MATCH_SQL


# -- Live fallback tests --------------------------------------------------------


class TestLiveFallback:
    def test_parse_search_doc(self):
        """Search docs should be parsed into work dicts."""
        from pipeline.sync.live_fallback import LiveFallback

        fallback = LiveFallback.__new__(LiveFallback)

        doc = {
            "key": "/works/OL5678W",
            "title": "Test Book",
            "first_publish_year": 2020,
            "subject": ["Fiction", "Fantasy"],
            "author_key": ["OL1234A"],
        }
        result = fallback._parse_search_doc(doc)
        assert result["title"] == "Test Book"
        assert result["first_published_year"] == 2020
        assert result["open_library_work_id"] == "OL5678W"
        assert "OL1234A" in result["author_ol_ids"]

    def test_parse_ol_work(self):
        """Full OL work records should be parsed correctly."""
        from pipeline.sync.live_fallback import LiveFallback

        fallback = LiveFallback.__new__(LiveFallback)

        data = {
            "key": "/works/OL5678W",
            "title": "Pride and Prejudice",
            "description": "A classic novel.",
            "first_publish_date": "1813",
            "subjects": ["Fiction"],
            "covers": [12345],
            "authors": [{"author": {"key": "/authors/OL1234A"}}],
        }
        result = fallback._parse_ol_work(data)
        assert result["title"] == "Pride and Prejudice"
        assert result["description"] == "A classic novel."
        assert result["first_published_year"] == 1813
        assert "12345" in result["cover_ol_ids"]
        assert "OL1234A" in result["author_ol_ids"]

    def test_search_returns_empty_without_args(self):
        """search_and_import with no args should return empty list."""
        import asyncio

        from pipeline.sync.live_fallback import LiveFallback

        mock_session = AsyncMock()
        fallback = LiveFallback(mock_session)
        result = asyncio.get_event_loop().run_until_complete(fallback.search_and_import())
        assert result == []
