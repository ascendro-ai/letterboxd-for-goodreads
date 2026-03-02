"""Nightly taste match computation.

Computes taste_matches for user pairs with 5+ shared rated books.
Score = (1 - avg_diff/4.5) * min(1, count/20)

Runs at 4am UTC via Railway cron.

Usage:
    python -m pipeline.sync.taste_match_job
"""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from pipeline.config import PipelineConfig, load_config
from pipeline.db import create_async_session_factory

logger = logging.getLogger(__name__)

# The full SQL for computing and upserting taste matches.
# Rating scale is 0.5–5.0, so max disagreement = |5.0 - 0.5| = 4.5
# Confidence weight: 20+ shared books = full weight. Fewer = linearly scaled down.
TASTE_MATCH_SQL = """
    INSERT INTO taste_matches (user_a_id, user_b_id, match_score, overlapping_books_count, computed_at)
    SELECT
        a.user_id AS user_a_id,
        b.user_id AS user_b_id,
        (1.0 - AVG(ABS(a.rating - b.rating)) / 4.5) * LEAST(1.0, COUNT(*)::float / 20.0) AS match_score,
        COUNT(*) AS overlapping_books_count,
        :computed_at AS computed_at
    FROM user_books a
    JOIN user_books b
        ON a.work_id = b.work_id
        AND a.user_id < b.user_id
    WHERE a.rating IS NOT NULL
        AND b.rating IS NOT NULL
    GROUP BY a.user_id, b.user_id
    HAVING COUNT(*) >= 5
    ON CONFLICT (user_a_id, user_b_id) DO UPDATE SET
        match_score = EXCLUDED.match_score,
        overlapping_books_count = EXCLUDED.overlapping_books_count,
        computed_at = EXCLUDED.computed_at
"""


async def compute_taste_matches(session: AsyncSession) -> int:
    """Run the taste match computation. Returns number of rows upserted."""
    now = datetime.now(timezone.utc)
    result = await session.execute(text(TASTE_MATCH_SQL), {"computed_at": now})
    await session.commit()
    return result.rowcount


async def run_taste_match_job(config: PipelineConfig | None = None) -> None:
    """Run the nightly taste match job."""
    if config is None:
        config = load_config()

    session_factory = create_async_session_factory(config)

    async with session_factory() as session:
        logger.info("Starting taste match computation")
        count = await compute_taste_matches(session)
        logger.info("Taste match computation complete: %d pairs updated", count)


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    asyncio.run(run_taste_match_job())


if __name__ == "__main__":
    main()
