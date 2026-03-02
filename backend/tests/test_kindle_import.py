"""Tests for Kindle clippings parser."""

import pytest

from backend.services.kindle_import_service import (
    KindleClipping,
    extract_unique_books,
    parse_kindle_clippings,
)


SAMPLE_CLIPPINGS = """The Great Gatsby (F. Scott Fitzgerald)
- Your Highlight on page 42 | location 645-650 | Added on Tuesday, January 15, 2026

So we beat on, boats against the current, borne back ceaselessly into the past.
==========
The Great Gatsby (F. Scott Fitzgerald)
- Your Highlight on page 12 | location 180-185 | Added on Monday, January 14, 2026

In my younger and more vulnerable years my father gave me some advice.
==========
Dune (Frank Herbert)
- Your Note on page 100 | location 1500-1505 | Added on Wednesday, February 5, 2026

Fear is the mind-killer.
==========
Dune (Frank Herbert)
- Your Bookmark on page 200 | location 3000 | Added on Thursday, February 6, 2026


==========
"""

MINIMAL_CLIPPINGS = """A Book Title
- Your Highlight on page 1

Some content
==========
"""


class TestParseKindleClippings:
    def test_parse_multiple_entries(self):
        clippings = parse_kindle_clippings(SAMPLE_CLIPPINGS)
        assert len(clippings) == 4

    def test_extract_title_and_author(self):
        clippings = parse_kindle_clippings(SAMPLE_CLIPPINGS)
        assert clippings[0].title == "The Great Gatsby"
        assert clippings[0].author == "F. Scott Fitzgerald"

    def test_highlight_type(self):
        clippings = parse_kindle_clippings(SAMPLE_CLIPPINGS)
        assert clippings[0].clipping_type == "Highlight"
        assert clippings[1].clipping_type == "Highlight"

    def test_note_type(self):
        clippings = parse_kindle_clippings(SAMPLE_CLIPPINGS)
        assert clippings[2].clipping_type == "Note"

    def test_bookmark_type(self):
        clippings = parse_kindle_clippings(SAMPLE_CLIPPINGS)
        assert clippings[3].clipping_type == "Bookmark"

    def test_highlight_content(self):
        clippings = parse_kindle_clippings(SAMPLE_CLIPPINGS)
        assert "boats against the current" in clippings[0].content

    def test_bookmark_has_no_content(self):
        clippings = parse_kindle_clippings(SAMPLE_CLIPPINGS)
        assert clippings[3].content is None

    def test_empty_input(self):
        clippings = parse_kindle_clippings("")
        assert clippings == []

    def test_no_author_in_title(self):
        clippings = parse_kindle_clippings(MINIMAL_CLIPPINGS)
        assert len(clippings) == 1
        assert clippings[0].title == "A Book Title"
        assert clippings[0].author is None

    def test_date_extraction(self):
        clippings = parse_kindle_clippings(SAMPLE_CLIPPINGS)
        assert clippings[0].date is not None
        assert "January 15, 2026" in clippings[0].date


class TestExtractUniqueBooks:
    def test_unique_books_count(self):
        clippings = parse_kindle_clippings(SAMPLE_CLIPPINGS)
        books = extract_unique_books(clippings)
        assert len(books) == 2  # Gatsby + Dune

    def test_highlight_counts(self):
        clippings = parse_kindle_clippings(SAMPLE_CLIPPINGS)
        books = extract_unique_books(clippings)
        gatsby = next(b for b in books if b["title"] == "The Great Gatsby")
        assert gatsby["highlight_count"] == 2
        assert gatsby["note_count"] == 0

    def test_note_counts(self):
        clippings = parse_kindle_clippings(SAMPLE_CLIPPINGS)
        books = extract_unique_books(clippings)
        dune = next(b for b in books if b["title"] == "Dune")
        assert dune["note_count"] == 1
        assert dune["bookmark_count"] == 1

    def test_empty_clippings(self):
        books = extract_unique_books([])
        assert books == []
