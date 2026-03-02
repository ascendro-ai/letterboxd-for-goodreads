"""Application configuration loaded from environment variables.

Settings are cached via @lru_cache so env is read once at startup.
"""

from functools import lru_cache

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://localhost/shelf"
    supabase_url: str = ""
    supabase_service_key: str = ""
    supabase_jwt_secret: str = ""
    sentry_dsn: str = ""
    cloudflare_r2_endpoint: str = ""
    cloudflare_r2_access_key: str = ""
    cloudflare_r2_secret_key: str = ""
    bookshop_affiliate_id: str = ""
    environment: str = "development"
    default_page_limit: int = 20
    max_page_limit: int = 100  # hard cap to prevent expensive unbounded queries
    max_shelves_free: int = 20  # premium unlocks unlimited shelves

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
