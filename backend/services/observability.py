"""
Observability service: Sentry error tracking and PostHog analytics.

All functions are no-ops when the respective service is not configured,
so callers never need to check configuration before calling.
"""

from __future__ import annotations

import logging
from typing import Any

logger = logging.getLogger(__name__)

# Module-level PostHog client reference. Set during init_posthog().
_posthog_client: Any = None


# ---------------------------------------------------------------------------
# Sentry initialization
# ---------------------------------------------------------------------------


def init_sentry(dsn: str, environment: str) -> None:
    """Initialize Sentry SDK with FastAPI integration.

    If dsn is empty, Sentry is not initialized and all capture calls are no-ops.
    """
    if not dsn:
        logger.info("Sentry DSN not configured -- skipping Sentry init")
        return

    import sentry_sdk

    sentry_sdk.init(
        dsn=dsn,
        environment=environment,
        traces_sample_rate=0.1,
        profiles_sample_rate=0.1,
        before_send=_sentry_before_send,
    )
    logger.info("Sentry initialized (environment=%s)", environment)


def _sentry_before_send(event: dict, hint: dict) -> dict | None:
    """Filter Sentry events: drop 4xx client errors, only capture 5xx."""
    if "exc_info" in hint:
        _exc_type, exc_value, _tb = hint["exc_info"]

        from fastapi import HTTPException

        if isinstance(exc_value, HTTPException) and 400 <= exc_value.status_code < 500:
            return None

        from backend.api.errors import AppError

        if isinstance(exc_value, AppError) and 400 <= exc_value.status_code < 500:
            return None

    return event


def set_sentry_user(user_id: str, username: str | None = None) -> None:
    """Attach user context to the current Sentry scope."""
    try:
        import sentry_sdk

        sentry_sdk.set_user({"id": user_id, "username": username or ""})
    except Exception:
        pass


def capture_exception(error: Exception, context: dict[str, Any] | None = None) -> None:
    """Capture an exception in Sentry with optional extra context."""
    try:
        import sentry_sdk

        with sentry_sdk.push_scope() as scope:
            if context:
                for key, value in context.items():
                    scope.set_extra(key, value)
            sentry_sdk.capture_exception(error)
    except Exception:
        logger.exception("Failed to capture exception in Sentry")


# ---------------------------------------------------------------------------
# PostHog initialization
# ---------------------------------------------------------------------------


def init_posthog(api_key: str, host: str) -> None:
    """Initialize the PostHog Python SDK.

    If api_key is empty, PostHog is not initialized and all calls are no-ops.
    """
    global _posthog_client

    if not api_key:
        logger.info("PostHog API key not configured -- skipping PostHog init")
        return

    try:
        from posthog import Posthog

        _posthog_client = Posthog(
            api_key=api_key,
            host=host,
            debug=False,
            on_error=_posthog_on_error,
        )
        logger.info("PostHog initialized (host=%s)", host)
    except ImportError:
        logger.warning("posthog package not installed -- skipping PostHog init")


def shutdown_posthog() -> None:
    """Flush and shut down the PostHog client."""
    global _posthog_client
    if _posthog_client is not None:
        try:
            _posthog_client.shutdown()
        except Exception:
            logger.exception("Error shutting down PostHog")
        _posthog_client = None


def _posthog_on_error(error: Exception, items: list) -> None:
    """PostHog error callback -- log but do not crash."""
    logger.warning("PostHog error: %s (items=%d)", error, len(items))


# ---------------------------------------------------------------------------
# PostHog event tracking
# ---------------------------------------------------------------------------


def track_event(
    user_id: str,
    event_name: str,
    properties: dict[str, Any] | None = None,
) -> None:
    """Track an analytics event in PostHog. No-op if not configured."""
    if _posthog_client is None or not user_id:
        return

    _posthog_client.capture(
        distinct_id=str(user_id),
        event=event_name,
        properties=properties or {},
    )


def identify_user(user_id: str, traits: dict[str, Any] | None = None) -> None:
    """Set user properties in PostHog. No-op if not configured."""
    if _posthog_client is None or not user_id:
        return

    _posthog_client.identify(
        distinct_id=str(user_id),
        properties=traits or {},
    )


# ---------------------------------------------------------------------------
# Standard event names
# ---------------------------------------------------------------------------


class Events:
    BOOK_LOGGED = "book_logged"
    BOOK_SEARCHED = "book_searched"
    IMPORT_STARTED = "import_started"
    IMPORT_COMPLETED = "import_completed"
    USER_SIGNED_UP = "user_signed_up"
    USER_FOLLOWED = "user_followed"
    SHELF_CREATED = "shelf_created"
    EXPORT_REQUESTED = "export_requested"
    BOOK_RATED = "book_rated"
    BOOK_REVIEWED = "book_reviewed"
    USER_BLOCKED = "user_blocked"
    USER_DELETED_ACCOUNT = "user_deleted_account"
