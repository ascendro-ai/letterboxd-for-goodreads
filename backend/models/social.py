import enum
import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, Index, func, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, PgJSONB


class Follow(Base):
    __tablename__ = "follows"

    follower_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    following_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
    )

    follower = relationship("User", foreign_keys=[follower_id], lazy="selectin")
    following = relationship("User", foreign_keys=[following_id], lazy="selectin")


class Block(Base):
    __tablename__ = "blocks"

    blocker_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    blocked_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
    )


class Mute(Base):
    __tablename__ = "mutes"

    muter_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    muted_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
    )


class ActivityType(enum.Enum):
    FINISHED_BOOK = "finished_book"
    STARTED_BOOK = "started_book"


class Activity(Base):
    __tablename__ = "activities"

    id: Mapped[uuid.UUID] = mapped_column(
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    activity_type: Mapped[ActivityType] = mapped_column(nullable=False)
    target_id: Mapped[uuid.UUID] = mapped_column(nullable=False)
    metadata_: Mapped[dict | None] = mapped_column("metadata", PgJSONB)
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
    )

    user = relationship("User", lazy="selectin")

    __table_args__ = (
        Index("ix_activities_user_created", "user_id", "created_at"),
    )
