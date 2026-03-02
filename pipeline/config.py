"""Pipeline configuration loaded from environment variables."""

from __future__ import annotations

import os
import uuid
from dataclasses import dataclass, field

from dotenv import load_dotenv

# Deterministic namespace for UUID5 — same OL ID always produces same UUID, making imports idempotent.
SHELF_UUID_NAMESPACE = uuid.UUID("a3f1b2c4-d5e6-7890-abcd-ef1234567890")

# Open Library dump URLs
OL_AUTHORS_DUMP_URL = "https://openlibrary.org/data/ol_dump_authors_latest.txt.gz"
OL_WORKS_DUMP_URL = "https://openlibrary.org/data/ol_dump_works_latest.txt.gz"
OL_EDITIONS_DUMP_URL = "https://openlibrary.org/data/ol_dump_editions_latest.txt.gz"


@dataclass(frozen=True)
class DatabaseConfig:
    """Database connection settings."""

    url: str
    sync_url: str  # psycopg3 sync URL for COPY operations

    @classmethod
    def from_env(cls) -> DatabaseConfig:
        async_url = os.environ["DATABASE_URL"]
        # Derive sync URL: asyncpg → psycopg for COPY bulk import
        sync_url = async_url.replace("postgresql+asyncpg://", "postgresql://")
        return cls(url=async_url, sync_url=sync_url)


@dataclass(frozen=True)
class R2Config:
    """Cloudflare R2 storage settings."""

    endpoint: str
    access_key: str
    secret_key: str
    bucket: str = "shelf-covers"

    @classmethod
    def from_env(cls) -> R2Config:
        return cls(
            endpoint=os.environ["CLOUDFLARE_R2_ENDPOINT"],
            access_key=os.environ["CLOUDFLARE_R2_ACCESS_KEY"],
            secret_key=os.environ["CLOUDFLARE_R2_SECRET_KEY"],
            bucket=os.environ.get("CLOUDFLARE_R2_BUCKET", "shelf-covers"),
        )


@dataclass(frozen=True)
class OpenLibraryConfig:
    """Open Library API settings."""

    base_url: str = "https://openlibrary.org"
    cover_base_url: str = "https://covers.openlibrary.org"
    recent_changes_limit: int = 1000


@dataclass(frozen=True)
class GoogleBooksConfig:
    """Google Books API settings."""

    api_key: str = ""
    daily_limit: int = 1000  # Google Books API free tier quota

    @classmethod
    def from_env(cls) -> GoogleBooksConfig:
        return cls(
            api_key=os.environ.get("GOOGLE_BOOKS_API_KEY", ""),
        )


@dataclass(frozen=True)
class PipelineConfig:
    """Top-level pipeline configuration."""

    db: DatabaseConfig
    r2: R2Config
    ol: OpenLibraryConfig = field(default_factory=OpenLibraryConfig)
    google_books: GoogleBooksConfig = field(default_factory=GoogleBooksConfig)
    batch_size: int = 10_000
    cover_concurrency: int = 50


def load_config() -> PipelineConfig:
    """Load pipeline config from environment variables."""
    load_dotenv()
    return PipelineConfig(
        db=DatabaseConfig.from_env(),
        r2=R2Config.from_env(),
        ol=OpenLibraryConfig(),
        google_books=GoogleBooksConfig.from_env(),
    )
