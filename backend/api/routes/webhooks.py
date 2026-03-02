"""Webhook receivers for third-party services."""

from __future__ import annotations

import logging

from backend.api.config import get_settings
from backend.api.deps import DB
from backend.api.model_stubs import User
from fastapi import APIRouter, Header, HTTPException, Request
from sqlalchemy import update

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/webhooks", tags=["webhooks"])


@router.post("/revenuecat")
async def revenuecat_webhook(
    request: Request,
    db: DB,
    authorization: str | None = Header(None),
) -> dict[str, str]:
    """Handle RevenueCat subscription events.

    Events: INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION, etc.
    Updates the user's is_premium flag in our database.
    """
    settings = get_settings()

    if settings.revenuecat_webhook_secret:
        if authorization != f"Bearer {settings.revenuecat_webhook_secret}":
            raise HTTPException(status_code=401, detail="Invalid webhook auth")

    body = await request.json()
    event_type = body.get("event", {}).get("type", "")
    app_user_id = body.get("event", {}).get("app_user_id", "")

    if not app_user_id:
        return {"status": "ignored"}

    grant_premium = event_type in (
        "INITIAL_PURCHASE",
        "RENEWAL",
        "PRODUCT_CHANGE",
        "UNCANCELLATION",
        "SUBSCRIBER_ALIAS",
    )
    revoke_premium = event_type in (
        "EXPIRATION",
        "BILLING_ISSUE",
    )

    if grant_premium or revoke_premium:
        await db.execute(
            update(User).where(User.id == app_user_id).values(is_premium=grant_premium)
        )
        logger.info(
            "RevenueCat %s for user %s → premium=%s", event_type, app_user_id, grant_premium
        )

    return {"status": "ok"}
