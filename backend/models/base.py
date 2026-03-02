import uuid
from datetime import datetime

from sqlalchemy import JSON, func, text
from sqlalchemy.dialects.postgresql import ARRAY as PG_ARRAY
from sqlalchemy.dialects.postgresql import JSONB as PG_JSONB
from sqlalchemy.orm import (
    DeclarativeBase,
    Mapped,
    mapped_column,
)
from sqlalchemy.types import TypeDecorator


class Base(DeclarativeBase):
    pass


class PgArray(TypeDecorator):
    """ARRAY on Postgres, JSON elsewhere (for test portability)."""

    impl = JSON
    cache_ok = True

    def __init__(self, item_type=None):
        super().__init__()
        self._item_type = item_type

    def load_dialect_impl(self, dialect):
        if dialect.name == "postgresql":
            return dialect.type_descriptor(PG_ARRAY(self._item_type))
        return dialect.type_descriptor(JSON())


class PgJSONB(TypeDecorator):
    """JSONB on Postgres, JSON elsewhere (for test portability)."""

    impl = JSON
    cache_ok = True

    def load_dialect_impl(self, dialect):
        if dialect.name == "postgresql":
            return dialect.type_descriptor(PG_JSONB())
        return dialect.type_descriptor(JSON())


class UUIDMixin:
    id: Mapped[uuid.UUID] = mapped_column(
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        onupdate=func.now(),
    )
