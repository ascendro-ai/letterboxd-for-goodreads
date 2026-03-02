"""Image format conversion — WebP with JPEG fallback."""

from __future__ import annotations

import io
import logging

from PIL import Image

logger = logging.getLogger(__name__)


def convert_to_webp(image_data: bytes) -> tuple[bytes, str]:
    """Convert image data to WebP format.

    Handles RGBA→RGB conversion for non-transparent images.
    Falls back to JPEG if WebP encoding fails.

    Returns:
        Tuple of (converted_bytes, content_type).
    """
    img = Image.open(io.BytesIO(image_data))

    # Convert RGBA → RGB (WebP supports alpha, but book covers don't need it)
    if img.mode == "RGBA":
        background = Image.new("RGB", img.size, (255, 255, 255))
        background.paste(img, mask=img.split()[3])
        img = background
    elif img.mode != "RGB":
        img = img.convert("RGB")

    # Try WebP first
    try:
        buf = io.BytesIO()
        # Quality 85 balances file size (~60% smaller than JPEG) with visual fidelity.
        img.save(buf, format="WEBP", quality=85)
        return buf.getvalue(), "image/webp"
    except Exception:
        logger.warning("WebP encoding failed, falling back to JPEG")

    # JPEG fallback
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=85)
    return buf.getvalue(), "image/jpeg"
