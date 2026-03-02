"""Tests for bulk import pipeline: parsers, helpers, and edge cases."""

from __future__ import annotations

import gzip
import uuid
from pathlib import Path
from unittest.mock import MagicMock, patch

import orjson
import pytest

from pipeline.config import SHELF_UUID_NAMESPACE
from pipeline.import_ol.helpers import (
    batched,
    extract_ol_id,
    extract_text_value,
    extract_year,
    generate_uuid,
    parse_tsv_json,
    stream_tsv_lines,
)
from pipeline.import_ol.parse_authors import parse_author, stream_authors
from pipeline.import_ol.parse_editions import (
    _normalize_format,
    parse_edition,
    stream_editions,
)
from pipeline.import_ol.parse_works import (
    _extract_author_ol_ids,
    _extract_cover_ids,
    parse_work,
    stream_works,
)


# -- Helper tests ---------------------------------------------------------------


class TestGenerateUUID:
    def test_deterministic(self):
        """Same OL ID always produces same UUID."""
        uuid1 = generate_uuid("OL1234A")
        uuid2 = generate_uuid("OL1234A")
        assert uuid1 == uuid2

    def test_different_ids_different_uuids(self):
        """Different OL IDs produce different UUIDs."""
        assert generate_uuid("OL1234A") != generate_uuid("OL5678W")

    def test_uses_uuid5(self):
        """Result matches expected UUID5 output."""
        expected = uuid.uuid5(SHELF_UUID_NAMESPACE, "OL1234A")
        assert generate_uuid("OL1234A") == expected


class TestExtractOlId:
    def test_author_key(self):
        assert extract_ol_id("/authors/OL1234A") == "OL1234A"

    def test_works_key(self):
        assert extract_ol_id("/works/OL5678W") == "OL5678W"

    def test_books_key(self):
        assert extract_ol_id("/books/OL9999M") == "OL9999M"

    def test_bare_id(self):
        assert extract_ol_id("OL1234A") == "OL1234A"


class TestExtractTextValue:
    def test_plain_string(self):
        assert extract_text_value("Hello") == "Hello"

    def test_dict_with_value(self):
        assert extract_text_value({"type": "/type/text", "value": "Hello"}) == "Hello"

    def test_none(self):
        assert extract_text_value(None) is None

    def test_empty_string(self):
        assert extract_text_value("") is None

    def test_whitespace_only(self):
        assert extract_text_value("   ") is None

    def test_dict_empty_value(self):
        assert extract_text_value({"type": "/type/text", "value": ""}) is None


class TestExtractYear:
    def test_simple_year(self):
        assert extract_year("2020") == 2020

    def test_full_date(self):
        assert extract_year("January 1, 2020") == 2020

    def test_iso_date(self):
        assert extract_year("2020-01-15") == 2020

    def test_circa_date(self):
        assert extract_year("c. 1985") == 1985

    def test_none(self):
        assert extract_year(None) is None

    def test_integer(self):
        assert extract_year(1984) == 1984

    def test_invalid_year(self):
        assert extract_year("no year here") is None

    def test_year_out_of_range(self):
        assert extract_year("0001") is None


class TestParseTsvJson:
    def test_valid_line(self, author_tsv_line: str):
        result = parse_tsv_json(author_tsv_line)
        assert result is not None
        assert result["name"] == "Jane Austen"

    def test_too_few_columns(self):
        assert parse_tsv_json("col1\tcol2\tcol3") is None

    def test_invalid_json(self):
        assert parse_tsv_json("a\tb\tc\td\t{invalid json}") is None


class TestBatched:
    def test_even_split(self):
        result = list(batched(range(10), 5))
        assert result == [[0, 1, 2, 3, 4], [5, 6, 7, 8, 9]]

    def test_uneven_split(self):
        result = list(batched(range(7), 3))
        assert result == [[0, 1, 2], [3, 4, 5], [6]]

    def test_empty(self):
        result = list(batched([], 5))
        assert result == []

    def test_single_batch(self):
        result = list(batched(range(3), 10))
        assert result == [[0, 1, 2]]


class TestStreamTsvLines:
    def test_reads_gzipped_file(self, tmp_path: Path):
        lines = ["line1\n", "line2\n", "line3\n"]
        gz_path = tmp_path / "test.gz"
        with gzip.open(gz_path, "wt", encoding="utf-8") as f:
            f.writelines(lines)
        result = list(stream_tsv_lines(gz_path))
        assert result == ["line1", "line2", "line3"]

    def test_skips_empty_lines(self, tmp_path: Path):
        lines = ["line1\n", "\n", "line2\n"]
        gz_path = tmp_path / "test.gz"
        with gzip.open(gz_path, "wt", encoding="utf-8") as f:
            f.writelines(lines)
        result = list(stream_tsv_lines(gz_path))
        assert result == ["line1", "line2"]


# -- Author parser tests -------------------------------------------------------


class TestParseAuthor:
    def test_valid_author(self, sample_author_json: dict):
        result = parse_author(sample_author_json)
        assert result is not None
        assert result["name"] == "Jane Austen"
        assert result["open_library_author_id"] == "OL1234A"
        assert result["bio"] == "English novelist known for her social commentary."

    def test_no_name_skipped(self):
        result = parse_author({"key": "/authors/OL0000A", "bio": "bio"})
        assert result is None

    def test_empty_name_skipped(self):
        result = parse_author({"key": "/authors/OL0000A", "name": "   "})
        assert result is None

    def test_bio_as_string(self):
        data = {"key": "/authors/OL1A", "name": "Test", "bio": "Simple string bio"}
        result = parse_author(data)
        assert result is not None
        assert result["bio"] == "Simple string bio"

    def test_uuid_is_deterministic(self, sample_author_json: dict):
        r1 = parse_author(sample_author_json)
        r2 = parse_author(sample_author_json)
        assert r1["id"] == r2["id"]


class TestStreamAuthors:
    def test_streams_from_gz(self, tmp_path: Path, sample_author_json: dict):
        tsv_line = f"/type/author\t/authors/OL1234A\t1\t2024-01-01\t{orjson.dumps(sample_author_json).decode()}\n"
        gz_path = tmp_path / "authors.gz"
        with gzip.open(gz_path, "wt", encoding="utf-8") as f:
            f.write(tsv_line)
        result = list(stream_authors(gz_path))
        assert len(result) == 1
        assert result[0]["name"] == "Jane Austen"


# -- Work parser tests ----------------------------------------------------------


class TestParseWork:
    def test_valid_work(self, sample_work_json: dict):
        result = parse_work(sample_work_json)
        assert result is not None
        assert result["title"] == "Pride and Prejudice"
        assert result["open_library_work_id"] == "OL5678W"
        assert result["first_published_year"] == 1813
        assert result["description"] == "A classic novel about the Bennet family."

    def test_no_title_skipped(self):
        result = parse_work({"key": "/works/OL0000W", "description": "No title"})
        assert result is None

    def test_subjects_extracted(self, sample_work_json: dict):
        result = parse_work(sample_work_json)
        assert result["subjects"] == ["Fiction", "Romance", "Classic Literature"]

    def test_empty_subjects(self):
        data = {"key": "/works/OL1W", "title": "Test"}
        result = parse_work(data)
        assert result["subjects"] is None


class TestExtractAuthorOlIds:
    def test_nested_dict_format(self):
        data = {"authors": [{"author": {"key": "/authors/OL1A"}}]}
        assert _extract_author_ol_ids(data) == ["OL1A"]

    def test_string_format(self):
        data = {"authors": [{"author": "/authors/OL2A"}]}
        assert _extract_author_ol_ids(data) == ["OL2A"]

    def test_key_format(self):
        data = {"authors": [{"key": "/authors/OL3A"}]}
        assert _extract_author_ol_ids(data) == ["OL3A"]

    def test_empty_authors(self):
        assert _extract_author_ol_ids({"authors": []}) == []

    def test_missing_authors(self):
        assert _extract_author_ol_ids({}) == []

    def test_non_list_authors(self):
        assert _extract_author_ol_ids({"authors": "invalid"}) == []


class TestExtractCoverIds:
    def test_valid_covers(self):
        data = {"covers": [12345, 67890]}
        assert _extract_cover_ids(data) == ["12345", "67890"]

    def test_filters_negative_ids(self):
        data = {"covers": [12345, -1, 67890]}
        assert _extract_cover_ids(data) == ["12345", "67890"]

    def test_empty_covers(self):
        assert _extract_cover_ids({"covers": []}) == []

    def test_missing_covers(self):
        assert _extract_cover_ids({}) == []


# -- Edition parser tests -------------------------------------------------------


class TestParseEdition:
    def test_valid_edition(self, sample_edition_json: dict):
        result = parse_edition(sample_edition_json)
        assert result is not None
        assert result["isbn_13"] == "9780141439518"
        assert result["isbn_10"] == "0141439513"
        assert result["publisher"] == "Penguin Classics"
        assert result["page_count"] == 480
        assert result["format"] == "paperback"
        assert result["language"] == "eng"
        assert result["open_library_edition_id"] == "OL9999M"

    def test_orphan_edition_skipped(self):
        """Editions without work reference should be skipped."""
        result = parse_edition({"key": "/books/OL0000M", "title": "Orphan"})
        assert result is None

    def test_edition_no_works_list(self):
        data = {"key": "/books/OL0000M", "works": "not a list"}
        assert parse_edition(data) is None

    def test_work_id_derived(self, sample_edition_json: dict):
        result = parse_edition(sample_edition_json)
        expected_work_uuid = generate_uuid("OL5678W")
        assert result["work_id"] == expected_work_uuid


class TestNormalizeFormat:
    def test_paperback(self):
        assert _normalize_format("Paperback") == "paperback"

    def test_hardcover(self):
        assert _normalize_format("Hardcover") == "hardcover"

    def test_hardback(self):
        assert _normalize_format("Hardback") == "hardcover"

    def test_ebook(self):
        assert _normalize_format("E-book") == "ebook"

    def test_kindle(self):
        assert _normalize_format("Kindle Edition") == "ebook"

    def test_audiobook(self):
        assert _normalize_format("Audio CD") == "audiobook"

    def test_unknown_format(self):
        assert _normalize_format("Scroll") is None

    def test_none(self):
        assert _normalize_format(None) is None

    def test_mass_market(self):
        assert _normalize_format("Mass Market Paperback") == "paperback"
