from __future__ import annotations

import time

from backend.services.observability import set_sentry_user, track_event
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint


class ObservabilityMiddleware(BaseHTTPMiddleware):
    """Request-level middleware that:
    1. Attaches user context to Sentry for authenticated requests.
    2. Adds request duration header.
    3. Tracks authenticated API requests in PostHog.
    """

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        start_time = time.monotonic()

        user_id = self._extract_user_id(request)
        if user_id:
            set_sentry_user(user_id)

        response = await call_next(request)

        duration_ms = round((time.monotonic() - start_time) * 1000, 2)
        response.headers["X-Request-Duration-Ms"] = str(duration_ms)

        if user_id and not self._is_internal_path(request.url.path):
            track_event(
                user_id=user_id,
                event_name="api_request",
                properties={
                    "method": request.method,
                    "path": request.url.path,
                    "status_code": response.status_code,
                    "duration_ms": duration_ms,
                },
            )

        return response

    @staticmethod
    def _extract_user_id(request: Request) -> str | None:
        """Lightweight JWT subject extraction without full validation."""
        auth_header = request.headers.get("authorization", "")
        if not auth_header.startswith("Bearer "):
            return None

        token = auth_header.removeprefix("Bearer ")
        try:
            import base64
            import json

            parts = token.split(".")
            if len(parts) != 3:
                return None

            payload_b64 = parts[1]
            padding = 4 - len(payload_b64) % 4
            if padding != 4:
                payload_b64 += "=" * padding

            payload = json.loads(base64.urlsafe_b64decode(payload_b64))
            return payload.get("sub")
        except Exception:
            return None

    @staticmethod
    def _is_internal_path(path: str) -> bool:
        """Return True for paths we do not want to track."""
        skip_prefixes = ("/health", "/api/docs", "/openapi.json")
        return any(path.startswith(prefix) for prefix in skip_prefixes)
