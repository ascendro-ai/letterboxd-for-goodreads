from __future__ import annotations

import pytest
from backend.services.reserved_usernames import (
    RESERVED_USERNAMES,
    is_username_reserved,
    validate_username_format,
)

# ---------------------------------------------------------------------------
# Unit tests — is_username_reserved
# ---------------------------------------------------------------------------


class TestIsUsernameReserved:
    def test_reserved_words_are_caught(self):
        for word in ["shelf", "admin", "api", "login", "goodreads", "booktok"]:
            assert is_username_reserved(word) is True

    def test_case_insensitivity(self):
        assert is_username_reserved("Shelf") is True
        assert is_username_reserved("ADMIN") is True
        assert is_username_reserved("GoOdReAdS") is True
        assert is_username_reserved("API") is True

    def test_leading_trailing_whitespace_stripped(self):
        assert is_username_reserved("  shelf  ") is True
        assert is_username_reserved(" admin") is True

    def test_non_reserved_usernames_pass(self):
        assert is_username_reserved("bookworm42") is False
        assert is_username_reserved("reader_jane") is False
        assert is_username_reserved("avid_reader") is False

    def test_reserved_set_is_frozen(self):
        assert isinstance(RESERVED_USERNAMES, frozenset)


# ---------------------------------------------------------------------------
# Unit tests — validate_username_format
# ---------------------------------------------------------------------------


class TestValidateUsernameFormat:
    def test_valid_usernames(self):
        assert validate_username_format("abc") is None
        assert validate_username_format("user_name") is None
        assert validate_username_format("a1b2c3") is None
        assert validate_username_format("reader42") is None
        assert validate_username_format("the_great_reader") is None
        assert validate_username_format("a" * 20) is None

    def test_too_short(self):
        error = validate_username_format("ab")
        assert error is not None
        assert "at least 3" in error

        error = validate_username_format("a")
        assert error is not None
        assert "at least 3" in error

        error = validate_username_format("")
        assert error is not None
        assert "at least 3" in error

    def test_too_long(self):
        error = validate_username_format("a" * 21)
        assert error is not None
        assert "at most 20" in error

    def test_special_characters_rejected(self):
        for username in ["user@name", "user name", "user-name", "user.name", "user!name"]:
            error = validate_username_format(username)
            assert error is not None, f"Expected rejection for '{username}'"

    def test_leading_underscore_rejected(self):
        error = validate_username_format("_username")
        assert error is not None
        assert "underscore" in error.lower()

    def test_trailing_underscore_rejected(self):
        error = validate_username_format("username_")
        assert error is not None
        assert "underscore" in error.lower()

    def test_consecutive_underscores_rejected(self):
        error = validate_username_format("user__name")
        assert error is not None
        assert "consecutive" in error.lower()

    def test_triple_underscores_rejected(self):
        error = validate_username_format("user___name")
        assert error is not None
        assert "consecutive" in error.lower()

    def test_exactly_three_chars(self):
        assert validate_username_format("abc") is None

    def test_exactly_twenty_chars(self):
        assert validate_username_format("a" * 20) is None


# ---------------------------------------------------------------------------
# Integration tests — PATCH /me with reserved/invalid username
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_update_profile_reserved_username_returns_422(client):
    response = await client.patch(
        "/api/v1/me",
        json={"username": "shelf"},
    )
    assert response.status_code == 422
    body = response.json()
    assert body["detail"]["error"]["code"] == "USERNAME_RESERVED"


@pytest.mark.asyncio
async def test_update_profile_too_short_username_returns_422(client):
    """Username 'ab' (2 chars) is rejected — Pydantic min_length catches it first."""
    response = await client.patch(
        "/api/v1/me",
        json={"username": "ab"},
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_update_profile_leading_underscore_username_returns_422(client):
    """Custom validation catches leading underscore."""
    response = await client.patch(
        "/api/v1/me",
        json={"username": "_badname"},
    )
    assert response.status_code == 422
    body = response.json()
    assert body["detail"]["error"]["code"] == "USERNAME_INVALID"


@pytest.mark.asyncio
async def test_update_profile_consecutive_underscores_returns_422(client):
    response = await client.patch(
        "/api/v1/me",
        json={"username": "my__name"},
    )
    assert response.status_code == 422
    body = response.json()
    assert body["detail"]["error"]["code"] == "USERNAME_INVALID"


@pytest.mark.asyncio
async def test_update_profile_valid_username_succeeds(client):
    response = await client.patch(
        "/api/v1/me",
        json={"username": "new_reader42"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["username"] == "new_reader42"
