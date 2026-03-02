"""Add is_private, hide_reading_stats, content tag tables.

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-03-02 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa

revision = "c3d4e5f6a7b8"
down_revision = "b2c3d4e5f6a7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Per-book privacy
    op.add_column("user_books", sa.Column("is_private", sa.Boolean(), server_default="false", nullable=False))

    # Hide reading stats preference
    op.add_column("users", sa.Column("hide_reading_stats", sa.Boolean(), server_default="false", nullable=False))

    # Content tags
    op.create_table(
        "work_content_tags",
        sa.Column("id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("work_id", sa.Uuid(), sa.ForeignKey("works.id", ondelete="CASCADE"), nullable=False),
        sa.Column("tag_name", sa.String(100), nullable=False),
        sa.Column("tag_type", sa.String(50), nullable=False),
        sa.Column("vote_count", sa.Integer(), server_default="0", nullable=False),
        sa.Column("is_confirmed", sa.Boolean(), server_default="false", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("work_id", "tag_name", name="uq_work_content_tag"),
    )
    op.create_index("ix_work_content_tags_work_id", "work_content_tags", ["work_id"])

    # Composite PK (user_id, work_content_tag_id) — one vote per user per tag
    op.create_table(
        "work_content_tag_votes",
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column(
            "work_content_tag_id",
            sa.Uuid(),
            sa.ForeignKey("work_content_tags.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("user_id", "work_content_tag_id"),
    )


def downgrade() -> None:
    op.drop_table("work_content_tag_votes")
    op.drop_table("work_content_tags")
    op.drop_column("users", "hide_reading_stats")
    op.drop_column("user_books", "is_private")
