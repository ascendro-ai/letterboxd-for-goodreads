"""initial schema

Revision ID: 92903d6f6b99
Revises:
Create Date: 2026-03-02 14:47:40.287769

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = '92903d6f6b99'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Enable required Postgres extensions
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    op.create_table('authors',
    sa.Column('name', sa.String(length=300), nullable=False),
    sa.Column('bio', sa.Text(), nullable=True),
    sa.Column('photo_url', sa.String(length=500), nullable=True),
    sa.Column('open_library_author_id', sa.String(length=50), nullable=True),
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
    sa.Column('updated_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_authors_name_trgm', 'authors', ['name'], unique=False, postgresql_using='gin', postgresql_ops={'name': 'gin_trgm_ops'})
    op.create_index(op.f('ix_authors_open_library_author_id'), 'authors', ['open_library_author_id'], unique=True)
    op.create_table('users',
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.Column('username', sa.String(length=30), nullable=False),
    sa.Column('display_name', sa.String(length=100), nullable=True),
    sa.Column('avatar_url', sa.String(length=500), nullable=True),
    sa.Column('bio', sa.Text(), nullable=True),
    sa.Column('favorite_books', postgresql.ARRAY(sa.Uuid()), nullable=True),
    sa.Column('is_premium', sa.Boolean(), server_default='false', nullable=False),
    sa.Column('deleted_at', sa.DateTime(), nullable=True),
    sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
    sa.Column('updated_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('username')
    )
    op.create_table('works',
    sa.Column('title', sa.String(length=500), nullable=False),
    sa.Column('original_title', sa.String(length=500), nullable=True),
    sa.Column('description', sa.Text(), nullable=True),
    sa.Column('first_published_year', sa.Integer(), nullable=True),
    sa.Column('open_library_work_id', sa.String(length=50), nullable=True),
    sa.Column('google_books_id', sa.String(length=50), nullable=True),
    sa.Column('subjects', postgresql.ARRAY(sa.String()), nullable=True),
    sa.Column('cover_image_url', sa.String(length=500), nullable=True),
    sa.Column('average_rating', sa.Numeric(precision=3, scale=2), nullable=True),
    sa.Column('ratings_count', sa.Integer(), server_default='0', nullable=False),
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
    sa.Column('updated_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_works_google_books_id'), 'works', ['google_books_id'], unique=True)
    op.create_index(op.f('ix_works_open_library_work_id'), 'works', ['open_library_work_id'], unique=True)
    op.create_index('ix_works_title_trgm', 'works', ['title'], unique=False, postgresql_using='gin', postgresql_ops={'title': 'gin_trgm_ops'})
    op.create_table('activities',
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('user_id', sa.Uuid(), nullable=False),
    sa.Column('activity_type', sa.String(30), nullable=False),
    sa.Column('target_id', sa.Uuid(), nullable=False),
    sa.Column('metadata', postgresql.JSONB(), nullable=True),
    sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_activities_user_created', 'activities', ['user_id', 'created_at'], unique=False)
    op.create_table('blocks',
    sa.Column('blocker_id', sa.Uuid(), nullable=False),
    sa.Column('blocked_id', sa.Uuid(), nullable=False),
    sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['blocked_id'], ['users.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['blocker_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('blocker_id', 'blocked_id')
    )
    op.create_table('editions',
    sa.Column('work_id', sa.Uuid(), nullable=False),
    sa.Column('isbn_10', sa.String(length=10), nullable=True),
    sa.Column('isbn_13', sa.String(length=13), nullable=True),
    sa.Column('publisher', sa.String(length=300), nullable=True),
    sa.Column('publish_date', sa.String(length=50), nullable=True),
    sa.Column('page_count', sa.Integer(), nullable=True),
    sa.Column('format', sa.String(50), nullable=True),
    sa.Column('language', sa.String(length=10), nullable=True),
    sa.Column('cover_image_url', sa.String(length=500), nullable=True),
    sa.Column('open_library_edition_id', sa.String(length=50), nullable=True),
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
    sa.Column('updated_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['work_id'], ['works.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_editions_isbn_10'), 'editions', ['isbn_10'], unique=False)
    op.create_index(op.f('ix_editions_isbn_13'), 'editions', ['isbn_13'], unique=False)
    op.create_index(op.f('ix_editions_open_library_edition_id'), 'editions', ['open_library_edition_id'], unique=True)
    op.create_table('follows',
    sa.Column('follower_id', sa.Uuid(), nullable=False),
    sa.Column('following_id', sa.Uuid(), nullable=False),
    sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['follower_id'], ['users.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['following_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('follower_id', 'following_id')
    )
    op.create_table('mutes',
    sa.Column('muter_id', sa.Uuid(), nullable=False),
    sa.Column('muted_id', sa.Uuid(), nullable=False),
    sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['muted_id'], ['users.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['muter_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('muter_id', 'muted_id')
    )
    op.create_table('shelves',
    sa.Column('user_id', sa.Uuid(), nullable=False),
    sa.Column('name', sa.String(length=100), nullable=False),
    sa.Column('slug', sa.String(length=100), nullable=False),
    sa.Column('description', sa.Text(), nullable=True),
    sa.Column('is_public', sa.Boolean(), server_default='true', nullable=False),
    sa.Column('display_order', sa.Integer(), server_default='0', nullable=False),
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
    sa.Column('updated_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('user_id', 'slug', name='uq_shelf_user_slug')
    )
    op.create_table('taste_matches',
    sa.Column('user_a_id', sa.Uuid(), nullable=False),
    sa.Column('user_b_id', sa.Uuid(), nullable=False),
    sa.Column('match_score', sa.Numeric(precision=4, scale=3), nullable=False),
    sa.Column('overlapping_books_count', sa.Integer(), nullable=False),
    sa.Column('computed_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['user_a_id'], ['users.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_b_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('user_a_id', 'user_b_id')
    )
    op.create_table('user_books',
    sa.Column('user_id', sa.Uuid(), nullable=False),
    sa.Column('work_id', sa.Uuid(), nullable=False),
    sa.Column('status', sa.String(20), nullable=False),
    sa.Column('rating', sa.Numeric(precision=2, scale=1), nullable=True),
    sa.Column('review_text', sa.Text(), nullable=True),
    sa.Column('has_spoilers', sa.Boolean(), server_default='false', nullable=False),
    sa.Column('started_at', sa.Date(), nullable=True),
    sa.Column('finished_at', sa.Date(), nullable=True),
    sa.Column('is_imported', sa.Boolean(), server_default='false', nullable=False),
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
    sa.Column('updated_at', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
    sa.CheckConstraint('rating IS NULL OR (rating >= 0.5 AND rating <= 5.0 AND rating * 2 = FLOOR(rating * 2))', name='ck_user_books_rating_range'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['work_id'], ['works.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('user_id', 'work_id', name='uq_user_book')
    )
    op.create_table('work_authors',
    sa.Column('work_id', sa.Uuid(), nullable=False),
    sa.Column('author_id', sa.Uuid(), nullable=False),
    sa.ForeignKeyConstraint(['author_id'], ['authors.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['work_id'], ['works.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('work_id', 'author_id')
    )
    op.create_table('shelf_books',
    sa.Column('shelf_id', sa.Uuid(), nullable=False),
    sa.Column('user_book_id', sa.Uuid(), nullable=False),
    sa.Column('position', sa.Integer(), server_default='0', nullable=False),
    sa.Column('id', sa.Uuid(), server_default=sa.text('gen_random_uuid()'), nullable=False),
    sa.ForeignKeyConstraint(['shelf_id'], ['shelves.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['user_book_id'], ['user_books.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('shelf_id', 'user_book_id', name='uq_shelf_book')
    )


def downgrade() -> None:
    op.drop_table('shelf_books')
    op.drop_table('work_authors')
    op.drop_table('user_books')
    op.drop_table('taste_matches')
    op.drop_table('shelves')
    op.drop_table('mutes')
    op.drop_table('follows')
    op.drop_index(op.f('ix_editions_open_library_edition_id'), table_name='editions')
    op.drop_index(op.f('ix_editions_isbn_13'), table_name='editions')
    op.drop_index(op.f('ix_editions_isbn_10'), table_name='editions')
    op.drop_table('editions')
    op.drop_table('blocks')
    op.drop_index('ix_activities_user_created', table_name='activities')
    op.drop_table('activities')
    op.drop_index('ix_works_title_trgm', table_name='works', postgresql_using='gin', postgresql_ops={'title': 'gin_trgm_ops'})
    op.drop_index(op.f('ix_works_open_library_work_id'), table_name='works')
    op.drop_index(op.f('ix_works_google_books_id'), table_name='works')
    op.drop_table('works')
    op.drop_table('users')
    op.drop_index(op.f('ix_authors_open_library_author_id'), table_name='authors')
    op.drop_index('ix_authors_name_trgm', table_name='authors', postgresql_using='gin', postgresql_ops={'name': 'gin_trgm_ops'})
    op.drop_table('authors')
    # No enum types to drop — columns use plain String
