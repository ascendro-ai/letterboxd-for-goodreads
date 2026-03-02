"""
Content moderation service.

LIMITATION: This is a placeholder — all content currently passes moderation.
Before launching, integrate a real moderation backend:
  - Perspective API (free, good for toxicity/harassment)
  - OpenAI moderation endpoint (free with API key)
  - AWS Comprehend (paid, supports PII detection)
Wire check_content() into user_book_service.log_book() and update_book()
to reject reviews that fail moderation.
"""

from __future__ import annotations


async def check_content(text: str) -> bool:
    """Check if text passes content moderation.

    Returns True if content is acceptable, False if it should be rejected.
    Currently a placeholder that always passes.
    """
    return True
