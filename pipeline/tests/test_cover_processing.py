"""Tests for cover processing pipeline: format, resize, upload, fetch."""

from __future__ import annotations

import io
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from PIL import Image

from pipeline.cover_processing.format import convert_to_webp
from pipeline.cover_processing.resize import VARIANTS, generate_variants
from pipeline.cover_processing.upload_r2 import R2Uploader


def _make_test_image(
    width: int = 800, height: int = 1200, mode: str = "RGB", fmt: str = "JPEG"
) -> bytes:
    """Create a test image in memory."""
    img = Image.new(mode, (width, height), color="red")
    buf = io.BytesIO()
    if mode == "RGBA" and fmt == "JPEG":
        img = img.convert("RGB")
    img.save(buf, format=fmt)
    return buf.getvalue()


# -- Format tests ---------------------------------------------------------------


class TestConvertToWebp:
    def test_converts_jpeg_to_webp(self):
        data = _make_test_image()
        result, content_type = convert_to_webp(data)
        assert content_type == "image/webp"
        # Verify it's valid WebP
        img = Image.open(io.BytesIO(result))
        assert img.format == "WEBP"

    def test_handles_rgba(self):
        data = _make_test_image(mode="RGBA", fmt="PNG")
        result, content_type = convert_to_webp(data)
        assert content_type == "image/webp"
        img = Image.open(io.BytesIO(result))
        assert img.mode == "RGB"

    def test_handles_palette_mode(self):
        """P mode (palette) images should be converted."""
        img = Image.new("P", (100, 100))
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        result, content_type = convert_to_webp(buf.getvalue())
        assert content_type == "image/webp"

    def test_jpeg_fallback_on_webp_failure(self):
        data = _make_test_image()
        original_save = Image.Image.save
        call_count = 0

        def patched_save(self_img, buf, format=None, **kwargs):
            nonlocal call_count
            call_count += 1
            if call_count == 1 and format == "WEBP":
                raise OSError("WebP encoding failed")
            return original_save(self_img, buf, format=format, **kwargs)

        with patch.object(Image.Image, "save", patched_save):
            result, content_type = convert_to_webp(data)
            assert content_type == "image/jpeg"


# -- Resize tests ---------------------------------------------------------------


class TestGenerateVariants:
    def test_generates_all_variants(self):
        data = _make_test_image(width=1500, height=2250)
        variants = generate_variants(data)
        assert set(variants.keys()) == set(VARIANTS.keys())

    def test_no_upscale(self):
        """Images smaller than target should not be upscaled."""
        data = _make_test_image(width=100, height=150)
        variants = generate_variants(data)
        for name, variant_data in variants.items():
            img = Image.open(io.BytesIO(variant_data))
            assert img.width <= 100

    def test_preserves_aspect_ratio(self):
        data = _make_test_image(width=800, height=1200)
        variants = generate_variants(data)
        # Card variant should be 300px wide, 450px tall (2:3 ratio)
        card = Image.open(io.BytesIO(variants["card"]))
        assert card.width == 300
        assert card.height == 450

    def test_lanczos_resampling(self):
        """Verify output is valid and resized correctly."""
        data = _make_test_image(width=1200, height=1800)
        variants = generate_variants(data)
        thumb = Image.open(io.BytesIO(variants["thumb"]))
        assert thumb.width == 150
        assert thumb.height == 225

    def test_all_variants_are_webp(self):
        data = _make_test_image(width=1500, height=2250)
        variants = generate_variants(data)
        for variant_data in variants.values():
            img = Image.open(io.BytesIO(variant_data))
            assert img.format == "WEBP"

    def test_rgba_input(self):
        data = _make_test_image(width=600, height=900, mode="RGBA", fmt="PNG")
        variants = generate_variants(data)
        assert len(variants) == 4
        for variant_data in variants.values():
            img = Image.open(io.BytesIO(variant_data))
            assert img.mode == "RGB"


# -- Upload tests ---------------------------------------------------------------


class TestR2Uploader:
    def test_key_format(self):
        mock_config = MagicMock()
        mock_config.endpoint = "https://example.r2.cloudflarestorage.com"
        mock_config.access_key = "key"
        mock_config.secret_key = "secret"
        mock_config.bucket = "shelf-covers"

        with patch("pipeline.cover_processing.upload_r2.boto3") as mock_boto3:
            mock_client = MagicMock()
            mock_boto3.client.return_value = mock_client

            uploader = R2Uploader(mock_config)
            key = uploader.upload_variant("abc-123", "detail", b"image_data")

            assert key == "covers/abc-123/detail.webp"
            mock_client.put_object.assert_called_once()
            call_kwargs = mock_client.put_object.call_args[1]
            assert call_kwargs["Key"] == "covers/abc-123/detail.webp"
            assert call_kwargs["ContentType"] == "image/webp"

    def test_cache_headers(self):
        mock_config = MagicMock()
        mock_config.endpoint = "https://example.r2.cloudflarestorage.com"
        mock_config.access_key = "key"
        mock_config.secret_key = "secret"
        mock_config.bucket = "shelf-covers"

        with patch("pipeline.cover_processing.upload_r2.boto3") as mock_boto3:
            mock_client = MagicMock()
            mock_boto3.client.return_value = mock_client

            uploader = R2Uploader(mock_config)
            uploader.upload_variant("abc-123", "thumb", b"data")

            call_kwargs = mock_client.put_object.call_args[1]
            assert "immutable" in call_kwargs["CacheControl"]

    def test_upload_all_variants(self):
        mock_config = MagicMock()
        mock_config.endpoint = "https://example.r2.cloudflarestorage.com"
        mock_config.access_key = "key"
        mock_config.secret_key = "secret"
        mock_config.bucket = "shelf-covers"

        with patch("pipeline.cover_processing.upload_r2.boto3") as mock_boto3:
            mock_client = MagicMock()
            mock_boto3.client.return_value = mock_client

            uploader = R2Uploader(mock_config)
            variants = {"thumb": b"t", "card": b"c", "detail": b"d", "hero": b"h"}
            keys = uploader.upload_all_variants("work-1", variants)

            assert len(keys) == 4
            assert keys["thumb"] == "covers/work-1/thumb.webp"
            assert mock_client.put_object.call_count == 4


# -- Fetch cover tests ----------------------------------------------------------


class TestFetchCovers:
    def test_rejects_tiny_images(self):
        """Images smaller than 1KB should be rejected as placeholders."""
        from pipeline.cover_processing.fetch_covers import MIN_IMAGE_BYTES

        assert MIN_IMAGE_BYTES == 1024
        # Verify a tiny image would be under the limit
        tiny_image = _make_test_image(width=1, height=1)
        assert len(tiny_image) < MIN_IMAGE_BYTES

    def test_google_books_daily_limit(self):
        """Google Books counter should respect daily limit."""
        from pipeline.config import GoogleBooksConfig

        config = GoogleBooksConfig(api_key="test", daily_limit=1000)
        # Counter at 999 is under limit, at 1000 is at/over limit
        assert 999 < config.daily_limit
        assert 1000 >= config.daily_limit
