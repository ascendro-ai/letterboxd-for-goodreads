from backend.services.import_service import (
    map_goodreads_status,
    normalize_isbn,
    parse_goodreads_isbn,
)


class TestParseGoodreadsIsbn:
    def test_standard_format(self):
        assert parse_goodreads_isbn('="0143127748"') == "0143127748"

    def test_plain_number(self):
        assert parse_goodreads_isbn("9780143127741") == "9780143127741"

    def test_with_hyphens(self):
        assert parse_goodreads_isbn("978-0-14-312774-1") == "9780143127741"

    def test_empty(self):
        assert parse_goodreads_isbn("") is None

    def test_only_quotes(self):
        assert parse_goodreads_isbn('=""') is None

    def test_curly_quotes(self):
        """Goodreads sometimes uses curly quotes."""
        assert parse_goodreads_isbn("=\u201c0143127748\u201d") == "0143127748"


class TestNormalizeIsbn:
    def test_strip_hyphens(self):
        assert normalize_isbn("978-0-14-312774-1") == "9780143127741"

    def test_strip_spaces(self):
        assert normalize_isbn("978 0143127741") == "9780143127741"

    def test_already_clean(self):
        assert normalize_isbn("9780143127741") == "9780143127741"


class TestMapGoodreadsStatus:
    def test_read(self):
        assert map_goodreads_status("read") == "read"

    def test_currently_reading(self):
        assert map_goodreads_status("currently-reading") == "reading"

    def test_to_read(self):
        assert map_goodreads_status("to-read") == "want_to_read"

    def test_unknown_defaults(self):
        assert map_goodreads_status("custom-shelf") == "want_to_read"

    def test_case_insensitive(self):
        assert map_goodreads_status("Read") == "read"
        assert map_goodreads_status("Currently-Reading") == "reading"
