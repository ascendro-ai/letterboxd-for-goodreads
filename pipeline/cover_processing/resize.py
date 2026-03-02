"""Generate cover image size variants."""

from __future__ import annotations

import io

from PIL import Image

# sm: list thumbnails, md: grid cards, lg: detail view, hero: full-screen display
# Variant definitions: name → max width in pixels
VARIANTS: dict[str, int] = {
    "thumb": 150,
    "card": 300,
    "detail": 600,
    "hero": 1200,
}


def generate_variants(image_data: bytes) -> dict[str, bytes]:
    """Generate all size variants from source image data.

    Each variant is resized to fit within its max width while preserving
    aspect ratio. Images smaller than the target width are NOT upscaled.
    Uses LANCZOS resampling for best quality.

    Returns:
        Dict mapping variant name → resized image bytes (WebP format).
    """
    img = Image.open(io.BytesIO(image_data))

    if img.mode == "RGBA":
        background = Image.new("RGB", img.size, (255, 255, 255))
        background.paste(img, mask=img.split()[3])
        img = background
    elif img.mode != "RGB":
        img = img.convert("RGB")

    original_width, original_height = img.size
    results: dict[str, bytes] = {}

    for variant_name, max_width in VARIANTS.items():
        # Don't upscale — if original is smaller, use original dimensions
        if original_width <= max_width:
            resized = img
        else:
            ratio = max_width / original_width
            new_height = int(original_height * ratio)
            resized = img.resize((max_width, new_height), Image.LANCZOS)

        buf = io.BytesIO()
        resized.save(buf, format="WEBP", quality=85)
        results[variant_name] = buf.getvalue()

    return results
