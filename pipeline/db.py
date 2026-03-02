"""Database connections: sync psycopg3 for COPY bulk import, async SQLAlchemy for jobs."""

from __future__ import annotations

from contextlib import contextmanager
from typing import TYPE_CHECKING, AsyncGenerator, Generator

import psycopg
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

if TYPE_CHECKING:
    from pipeline.config import PipelineConfig


def get_sync_connection(config: PipelineConfig) -> psycopg.Connection:
    """Create a sync psycopg3 connection for COPY bulk imports."""
    return psycopg.connect(config.db.sync_url, autocommit=False)


@contextmanager
def sync_connection(config: PipelineConfig) -> Generator[psycopg.Connection, None, None]:
    """Context manager for sync psycopg3 connection."""
    conn = get_sync_connection(config)
    try:
        yield conn
    finally:
        conn.close()


def create_async_engine_from_config(config: PipelineConfig):
    """Create an async SQLAlchemy engine."""
    return create_async_engine(config.db.url, echo=False, pool_size=5, max_overflow=10)


def create_async_session_factory(config: PipelineConfig) -> async_sessionmaker[AsyncSession]:
    """Create an async session factory for sync jobs and queries."""
    engine = create_async_engine_from_config(config)
    return async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def get_async_session(
    config: PipelineConfig,
) -> AsyncGenerator[AsyncSession, None]:
    """Yield an async session for use in async with blocks."""
    factory = create_async_session_factory(config)
    async with factory() as session:
        yield session
