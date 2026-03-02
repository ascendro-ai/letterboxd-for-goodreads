"""Apple Push Notification Service (APNs) HTTP/2 client.

Sends push notifications to iOS devices via APNs using JWT-based authentication.
The JWT is cached and refreshed every 50 minutes (Apple allows 60-minute tokens).
"""

from __future__ import annotations

import logging
import time
from pathlib import Path

from backend.api.config import get_settings

logger = logging.getLogger(__name__)

# APNs endpoints
APNS_PRODUCTION = "https://api.push.apple.com"
APNS_SANDBOX = "https://api.sandbox.push.apple.com"

# JWT refresh interval (50 minutes; Apple allows 60)
JWT_REFRESH_SECONDS = 50 * 60

_cached_jwt: str | None = None
_jwt_issued_at: float = 0


class InvalidTokenError(Exception):
    """Raised when APNs reports a device token as invalid (410 Gone)."""


def _generate_jwt() -> str:
    """Generate a new ES256 JWT for APNs authentication."""
    global _cached_jwt, _jwt_issued_at

    now = time.time()
    if _cached_jwt and (now - _jwt_issued_at) < JWT_REFRESH_SECONDS:
        return _cached_jwt

    settings = get_settings()
    if not settings.apns_key_path or not settings.apns_key_id or not settings.apns_team_id:
        raise RuntimeError("APNs key not configured (APNS_KEY_PATH, APNS_KEY_ID, APNS_TEAM_ID)")

    import jwt as pyjwt

    key_data = Path(settings.apns_key_path).read_bytes()

    token = pyjwt.encode(
        {"iss": settings.apns_team_id, "iat": int(now)},
        key_data,
        algorithm="ES256",
        headers={"kid": settings.apns_key_id},
    )

    _cached_jwt = token
    _jwt_issued_at = now
    return token


async def send_push(device_token: str, title: str, body: str, data: dict | None = None) -> None:
    """Send a push notification to a single iOS device.

    Raises InvalidTokenError if the device token is no longer valid.
    """
    settings = get_settings()
    if not settings.apns_key_path:
        logger.debug("APNs not configured — skipping push")
        return

    import httpx

    base_url = APNS_SANDBOX if settings.apns_use_sandbox else APNS_PRODUCTION
    url = f"{base_url}/3/device/{device_token}"

    jwt_token = _generate_jwt()

    payload = {
        "aps": {
            "alert": {"title": title, "body": body},
            "sound": "default",
        },
    }
    if data:
        payload["data"] = data

    headers = {
        "authorization": f"bearer {jwt_token}",
        "apns-topic": settings.apns_bundle_id,
        "apns-push-type": "alert",
    }

    try:
        async with httpx.AsyncClient(http2=True, timeout=10.0) as client:
            response = await client.post(url, json=payload, headers=headers)

        if response.status_code == 200:
            return
        if response.status_code == 410:
            raise InvalidTokenError(f"Device token {device_token} is no longer valid")
        if response.status_code == 403:
            # JWT expired mid-request — clear cache and retry once
            global _cached_jwt
            _cached_jwt = None
            jwt_token = _generate_jwt()
            headers["authorization"] = f"bearer {jwt_token}"
            async with httpx.AsyncClient(http2=True, timeout=10.0) as client:
                response = await client.post(url, json=payload, headers=headers)
            if response.status_code != 200:
                logger.error("APNs retry failed: %d %s", response.status_code, response.text)
        else:
            logger.error("APNs error: %d %s", response.status_code, response.text)

    except InvalidTokenError:
        raise
    except Exception as e:
        logger.error("APNs request failed: %s", str(e))
