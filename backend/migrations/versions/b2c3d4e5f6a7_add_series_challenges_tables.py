"""add series and reading challenges tables

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-03-02 20:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b2c3d4e5f6a7'
down_revision: Union[str, None] = 'a1b2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Series table
    op.create_table(
        'series',
        sa.Column('id', sa.dialects.postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('name', sa.String(300), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('total_books', sa.Integer(), nullable=True),
        sa.Column('is_complete', sa.Boolean(), server_default='false', nullable=False),
        sa.Column('cover_image_url', sa.String(500), nullable=True),
        sa.Column('open_library_series_id', sa.String(50), nullable=True, unique=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # Series-works junction table
    op.create_table(
        'series_works',
        sa.Column('id', sa.dialects.postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('series_id', sa.dialects.postgresql.UUID(as_uuid=True),
                  sa.ForeignKey('series.id', ondelete='CASCADE'), nullable=False),
        sa.Column('work_id', sa.dialects.postgresql.UUID(as_uuid=True),
                  sa.ForeignKey('works.id', ondelete='CASCADE'), nullable=False),
        sa.Column('position', sa.Numeric(5, 1), nullable=False),
        sa.Column('is_main_entry', sa.Boolean(), server_default='true', nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint('series_id', 'work_id', name='uq_series_work'),
    )
    op.create_index('ix_series_works_series_position', 'series_works', ['series_id', 'position'])
    op.create_index('ix_series_works_series_id', 'series_works', ['series_id'])
    op.create_index('ix_series_works_work_id', 'series_works', ['work_id'])

    # Reading challenges table
    op.create_table(
        'reading_challenges',
        sa.Column('id', sa.dialects.postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', sa.dialects.postgresql.UUID(as_uuid=True),
                  sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('year', sa.Integer(), nullable=False),
        sa.Column('goal_count', sa.Integer(), nullable=False),
        sa.Column('current_count', sa.Integer(), server_default='0', nullable=False),
        sa.Column('is_complete', sa.Boolean(), server_default='false', nullable=False),
        sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint('user_id', 'year', name='uq_challenge_user_year'),
    )

    # Challenge-books junction table
    op.create_table(
        'challenge_books',
        sa.Column('id', sa.dialects.postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('challenge_id', sa.dialects.postgresql.UUID(as_uuid=True),
                  sa.ForeignKey('reading_challenges.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('user_book_id', sa.dialects.postgresql.UUID(as_uuid=True),
                  sa.ForeignKey('user_books.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint('challenge_id', 'user_book_id', name='uq_challenge_book'),
    )


def downgrade() -> None:
    op.drop_table('challenge_books')
    op.drop_table('reading_challenges')
    op.drop_table('series_works')
    op.drop_table('series')
