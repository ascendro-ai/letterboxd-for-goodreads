import uuid
from datetime import datetime

from sqlalchemy import String, Text
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base, PgArray, TimestampMixin


class User(TimestampMixin, Base):
    __tablename__ = "users"

    # UUID provided by Supabase Auth — no server_default
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True)
    username: Mapped[str] = mapped_column(
        String(30), unique=True, nullable=False
    )
    display_name: Mapped[str | None] = mapped_column(String(100))
    avatar_url: Mapped[str | None] = mapped_column(String(500))
    bio: Mapped[str | None] = mapped_column(Text)
    favorite_books: Mapped[list[uuid.UUID] | None] = mapped_column(
        PgArray(String)
    )
    is_premium: Mapped[bool] = mapped_column(default=False, server_default="false")
    deleted_at: Mapped[datetime | None] = mapped_column()
