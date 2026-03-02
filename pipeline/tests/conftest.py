"""Shared test fixtures for pipeline tests."""

from __future__ import annotations

import json
from pathlib import Path

import orjson
import pytest

FIXTURES_DIR = Path(__file__).parent / "fixtures"


def _make_tsv_line(type_str: str, key: str, revision: int, json_data: dict) -> str:
    """Build a fake OL dump TSV line."""
    return f"{type_str}\t{key}\t{revision}\t2024-01-01T00:00:00\t{orjson.dumps(json_data).decode()}"


@pytest.fixture
def sample_author_json() -> dict:
    return json.loads((FIXTURES_DIR / "sample_author.json").read_text())


@pytest.fixture
def sample_work_json() -> dict:
    return json.loads((FIXTURES_DIR / "sample_work.json").read_text())


@pytest.fixture
def sample_edition_json() -> dict:
    return json.loads((FIXTURES_DIR / "sample_edition.json").read_text())


@pytest.fixture
def sample_recent_changes() -> list[dict]:
    return json.loads((FIXTURES_DIR / "sample_recent_changes.json").read_text())


@pytest.fixture
def author_tsv_line(sample_author_json: dict) -> str:
    return _make_tsv_line("/type/author", "/authors/OL1234A", 1, sample_author_json)


@pytest.fixture
def work_tsv_line(sample_work_json: dict) -> str:
    return _make_tsv_line("/type/work", "/works/OL5678W", 1, sample_work_json)


@pytest.fixture
def edition_tsv_line(sample_edition_json: dict) -> str:
    return _make_tsv_line("/type/edition", "/books/OL9999M", 1, sample_edition_json)


@pytest.fixture
def author_tsv_no_name() -> str:
    """Author TSV line with missing name — should be skipped."""
    data = {"key": "/authors/OL0000A", "bio": "Some bio", "type": {"key": "/type/author"}}
    return _make_tsv_line("/type/author", "/authors/OL0000A", 1, data)


@pytest.fixture
def work_tsv_no_title() -> str:
    """Work TSV line with missing title — should be skipped."""
    data = {"key": "/works/OL0000W", "description": "No title work", "type": {"key": "/type/work"}}
    return _make_tsv_line("/type/work", "/works/OL0000W", 1, data)


@pytest.fixture
def edition_tsv_orphan() -> str:
    """Edition TSV line with no work reference — should be skipped."""
    data = {"key": "/books/OL0000M", "title": "Orphan Edition", "type": {"key": "/type/edition"}}
    return _make_tsv_line("/type/edition", "/books/OL0000M", 1, data)
