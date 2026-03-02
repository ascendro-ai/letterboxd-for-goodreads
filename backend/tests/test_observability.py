from __future__ import annotations

from unittest.mock import MagicMock

import pytest
from backend.services.observability import (
    _sentry_before_send,
    capture_exception,
    identify_user,
    set_sentry_user,
    track_event,
)


class TestSentryBeforeSend:
    def test_allows_5xx_exceptions(self):
        from fastapi import HTTPException

        event = {"level": "error"}
        hint = {"exc_info": (HTTPException, HTTPException(status_code=500), None)}
        result = _sentry_before_send(event, hint)
        assert result is not None

    def test_filters_4xx_http_exceptions(self):
        from fastapi import HTTPException

        event = {"level": "error"}
        hint = {"exc_info": (HTTPException, HTTPException(status_code=404), None)}
        result = _sentry_before_send(event, hint)
        assert result is None

    def test_filters_4xx_app_errors(self):
        from backend.api.errors import AppError

        event = {"level": "error"}
        err = AppError(422, "TEST", "test error")
        hint = {"exc_info": (AppError, err, None)}
        result = _sentry_before_send(event, hint)
        assert result is None

    def test_allows_non_http_exceptions(self):
        event = {"level": "error"}
        hint = {"exc_info": (ValueError, ValueError("test"), None)}
        result = _sentry_before_send(event, hint)
        assert result is not None

    def test_allows_events_without_exc_info(self):
        event = {"level": "error"}
        hint = {}
        result = _sentry_before_send(event, hint)
        assert result is not None


class TestTrackEvent:
    def test_no_op_without_client(self):
        """Should not raise when PostHog is not initialized."""
        track_event("user123", "test_event", {"key": "value"})

    def test_no_op_with_empty_user_id(self):
        """Should not raise with empty user_id."""
        track_event("", "test_event")


class TestIdentifyUser:
    def test_no_op_without_client(self):
        """Should not raise when PostHog is not initialized."""
        identify_user("user123", {"username": "test"})

    def test_no_op_with_empty_user_id(self):
        """Should not raise with empty user_id."""
        identify_user("", {"username": "test"})


class TestSetSentryUser:
    def test_no_op_without_sentry(self):
        """Should not raise when Sentry is not initialized."""
        set_sentry_user("user123", "testuser")


class TestCaptureException:
    def test_no_op_without_sentry(self):
        """Should not raise when Sentry is not initialized."""
        capture_exception(ValueError("test"), {"context": "test"})


@pytest.mark.asyncio
async def test_middleware_adds_duration_header(client):
    """Observability middleware adds X-Request-Duration-Ms header."""
    resp = await client.get("/health")
    assert resp.status_code == 200
    assert "x-request-duration-ms" in resp.headers


class TestMiddlewareExtractUserId:
    def test_extracts_from_valid_jwt(self):
        import base64
        import json

        from backend.api.middleware.observability import ObservabilityMiddleware

        payload = {"sub": "user-123"}
        payload_b64 = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip("=")
        token = f"header.{payload_b64}.signature"

        request = MagicMock()
        request.headers = {"authorization": f"Bearer {token}"}
        result = ObservabilityMiddleware._extract_user_id(request)
        assert result == "user-123"

    def test_returns_none_for_no_auth_header(self):
        from backend.api.middleware.observability import ObservabilityMiddleware

        request = MagicMock()
        request.headers = {}
        result = ObservabilityMiddleware._extract_user_id(request)
        assert result is None

    def test_returns_none_for_invalid_token(self):
        from backend.api.middleware.observability import ObservabilityMiddleware

        request = MagicMock()
        request.headers = {"authorization": "Bearer invalid"}
        result = ObservabilityMiddleware._extract_user_id(request)
        assert result is None

    def test_is_internal_path(self):
        from backend.api.middleware.observability import ObservabilityMiddleware

        assert ObservabilityMiddleware._is_internal_path("/health") is True
        assert ObservabilityMiddleware._is_internal_path("/api/docs") is True
        assert ObservabilityMiddleware._is_internal_path("/api/v1/books") is False
