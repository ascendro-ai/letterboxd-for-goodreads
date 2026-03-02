"""Upload cover images to Cloudflare R2."""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING

import boto3

if TYPE_CHECKING:
    from pipeline.config import R2Config

logger = logging.getLogger(__name__)


class R2Uploader:
    """Upload cover image variants to Cloudflare R2 with S3-compatible API."""

    def __init__(self, config: R2Config) -> None:
        self._config = config
        self._client = boto3.client(
            "s3",
            endpoint_url=config.endpoint,
            aws_access_key_id=config.access_key,
            aws_secret_access_key=config.secret_key,
        )

    def upload_variant(
        self,
        work_id: str,
        variant_name: str,
        image_data: bytes,
        content_type: str = "image/webp",
    ) -> str:
        """Upload a single cover variant to R2.

        Key pattern: covers/{work_id}/{variant}.webp

        Returns the CDN URL of the uploaded image.
        """
        ext = "webp" if "webp" in content_type else "jpg"
        key = f"covers/{work_id}/{variant_name}.{ext}"

        self._client.put_object(
            Bucket=self._config.bucket,
            Key=key,
            Body=image_data,
            ContentType=content_type,
            CacheControl="public, max-age=31536000, immutable",
        )
        logger.debug("Uploaded %s", key)
        return key

    def upload_all_variants(
        self,
        work_id: str,
        variants: dict[str, bytes],
        content_type: str = "image/webp",
    ) -> dict[str, str]:
        """Upload all cover variants for a work.

        Returns dict mapping variant name → R2 key.
        """
        keys: dict[str, str] = {}
        for variant_name, image_data in variants.items():
            keys[variant_name] = self.upload_variant(
                work_id, variant_name, image_data, content_type
            )
        return keys
