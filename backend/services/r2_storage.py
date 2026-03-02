"""
Cloudflare R2 storage helpers.

R2 is S3-compatible, so we use boto3 with a custom endpoint.
"""

from __future__ import annotations

import logging

from backend.api.config import get_settings

logger = logging.getLogger(__name__)

EXPORT_BUCKET = "shelf-exports"


def _get_s3_client():
    """Create an S3-compatible client configured for Cloudflare R2."""
    import boto3
    from botocore.config import Config

    settings = get_settings()
    return boto3.client(
        "s3",
        endpoint_url=settings.cloudflare_r2_endpoint,
        aws_access_key_id=settings.cloudflare_r2_access_key,
        aws_secret_access_key=settings.cloudflare_r2_secret_key,
        config=Config(
            signature_version="s3v4",
            region_name="auto",
        ),
    )


def upload_to_r2(data: bytes, key: str) -> str:
    """Upload bytes to R2 and return the object key.

    Args:
        data: The file content as bytes.
        key: The S3 object key (e.g. "exports/{user_id}/{export_id}.json").

    Returns:
        The object key that was uploaded.

    Raises:
        AppError: If the upload fails.
    """
    from backend.api.errors import AppError

    try:
        client = _get_s3_client()
        client.put_object(
            Bucket=EXPORT_BUCKET,
            Key=key,
            Body=data,
            ContentType="application/json",
        )
        return key
    except Exception as e:
        logger.error("R2 upload failed for key %s: %s", key, str(e))
        raise AppError(
            status_code=500,
            code="UPLOAD_FAILED",
            message="Failed to upload export file.",
        ) from e


def generate_signed_url(key: str, expires_in: int = 86400) -> str:
    """Generate a pre-signed download URL for an R2 object.

    Args:
        key: The S3 object key.
        expires_in: URL expiry in seconds. Defaults to 86400 (24 hours).

    Returns:
        A pre-signed URL string.
    """
    from backend.api.errors import AppError

    try:
        client = _get_s3_client()
        url = client.generate_presigned_url(
            "get_object",
            Params={
                "Bucket": EXPORT_BUCKET,
                "Key": key,
            },
            ExpiresIn=expires_in,
        )
        return url
    except Exception as e:
        logger.error("R2 signed URL generation failed for key %s: %s", key, str(e))
        raise AppError(
            status_code=500,
            code="SIGNED_URL_FAILED",
            message="Failed to generate download URL.",
        ) from e
