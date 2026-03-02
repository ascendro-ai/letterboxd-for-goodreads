"""Tests for ORM model stubs — verifies schema, relationships, and constraints."""

import uuid
from datetime import datetime, timezone
from decimal import Decimal

import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from backend.api.model_stubs import (
    Activity,
    Author,
    Block,
    Edition,
    Follow,
    Mute,
    Shelf,
    ShelfBook,
    TasteMatch,
    User,
    UserBook,
    Work,
)


# --- Helpers ---


def make_user(**kwargs) -> User:
    defaults = {
        "id": str(uuid.uuid4()),
        "username": f"user_{uuid.uuid4().hex[:8]}",
        "is_premium": False,
        "is_deleted": False,
    }
    defaults.update(kwargs)
    return User(**defaults)


def make_work(**kwargs) -> Work:
    defaults = {
        "id": str(uuid.uuid4()),
        "title": "Test Book",
        "ratings_count": 0,
    }
    defaults.update(kwargs)
    return Work(**defaults)


# --- Work model ---


class TestWork:
    async def test_create_work(self, db_session: AsyncSession):
        work = make_work(title="Dune", first_published_year=1965)
        db_session.add(work)
        await db_session.flush()

        result = await db_session.get(Work, work.id)
        assert result is not None
        assert result.title == "Dune"
        assert result.first_published_year == 1965

    async def test_work_with_subjects(self, db_session: AsyncSession):
        work = make_work(subjects=["fiction", "sci-fi"])
        db_session.add(work)
        await db_session.flush()

        result = await db_session.get(Work, work.id)
        assert result.subjects == ["fiction", "sci-fi"]

    async def test_work_defaults(self, db_session: AsyncSession):
        work = make_work()
        db_session.add(work)
        await db_session.flush()

        result = await db_session.get(Work, work.id)
        assert result.ratings_count == 0
        assert result.average_rating is None


# --- Author model ---


class TestAuthor:
    async def test_create_author(self, db_session: AsyncSession):
        author = Author(id=str(uuid.uuid4()), name="Frank Herbert")
        db_session.add(author)
        await db_session.flush()

        result = await db_session.get(Author, author.id)
        assert result.name == "Frank Herbert"

    async def test_work_author_relationship(self, db_session: AsyncSession):
        author = Author(id=str(uuid.uuid4()), name="Tolkien")
        work = make_work(title="The Hobbit")
        work.authors.append(author)
        db_session.add(work)
        await db_session.flush()

        result = await db_session.get(Work, work.id)
        assert len(result.authors) == 1
        assert result.authors[0].name == "Tolkien"


# --- Edition model ---


class TestEdition:
    async def test_create_edition(self, db_session: AsyncSession):
        work = make_work()
        db_session.add(work)
        await db_session.flush()

        edition = Edition(
            id=str(uuid.uuid4()),
            work_id=work.id,
            isbn_13="9780441013593",
            publisher="Ace Books",
            format="paperback",
            page_count=688,
        )
        db_session.add(edition)
        await db_session.flush()

        result = await db_session.get(Edition, edition.id)
        assert result.isbn_13 == "9780441013593"
        assert result.format == "paperback"


# --- User model ---


class TestUser:
    async def test_create_user(self, db_session: AsyncSession):
        user = make_user(username="bookworm", display_name="Book Worm")
        db_session.add(user)
        await db_session.flush()

        result = await db_session.get(User, user.id)
        assert result.username == "bookworm"
        assert result.display_name == "Book Worm"
        assert result.is_premium is False

    async def test_unique_username(self, db_session: AsyncSession):
        user1 = make_user(username="unique_name")
        user2 = make_user(username="unique_name")
        db_session.add(user1)
        await db_session.flush()
        db_session.add(user2)
        with pytest.raises(IntegrityError):
            await db_session.flush()
        await db_session.rollback()

    async def test_soft_delete(self, db_session: AsyncSession):
        user = make_user()
        db_session.add(user)
        await db_session.flush()

        user.deleted_at = datetime.now(timezone.utc)
        await db_session.flush()

        result = await db_session.get(User, user.id)
        assert result.deleted_at is not None


# --- UserBook model ---


class TestUserBook:
    async def test_create_user_book(self, db_session: AsyncSession):
        user = make_user()
        work = make_work()
        db_session.add_all([user, work])
        await db_session.flush()

        ub = UserBook(
            id=str(uuid.uuid4()),
            user_id=user.id,
            work_id=work.id,
            status="read",
            rating=Decimal("4.5"),
            review_text="Great book!",
        )
        db_session.add(ub)
        await db_session.flush()

        result = await db_session.get(UserBook, ub.id)
        assert result.status == "read"
        assert result.rating == Decimal("4.5")
        assert result.is_imported is False

    async def test_user_book_different_statuses(self, db_session: AsyncSession):
        user = make_user()
        db_session.add(user)
        await db_session.flush()

        statuses = ["reading", "read", "want_to_read", "did_not_finish"]
        for status in statuses:
            work = make_work()
            db_session.add(work)
            await db_session.flush()

            ub = UserBook(
                id=str(uuid.uuid4()),
                user_id=user.id,
                work_id=work.id,
                status=status,
            )
            db_session.add(ub)
            await db_session.flush()

            result = await db_session.get(UserBook, ub.id)
            assert result.status == status

    async def test_imported_book(self, db_session: AsyncSession):
        user = make_user()
        work = make_work()
        db_session.add_all([user, work])
        await db_session.flush()

        ub = UserBook(
            id=str(uuid.uuid4()),
            user_id=user.id,
            work_id=work.id,
            status="read",
            rating=Decimal("3.0"),
            is_imported=True,
        )
        db_session.add(ub)
        await db_session.flush()

        result = await db_session.get(UserBook, ub.id)
        assert result.is_imported is True


# --- Shelf model ---


class TestShelf:
    async def test_create_shelf(self, db_session: AsyncSession):
        user = make_user()
        db_session.add(user)
        await db_session.flush()

        shelf = Shelf(
            id=str(uuid.uuid4()),
            user_id=user.id,
            name="Favorites",
            slug="favorites",
        )
        db_session.add(shelf)
        await db_session.flush()

        result = await db_session.get(Shelf, shelf.id)
        assert result.name == "Favorites"
        assert result.is_public is True
        assert result.display_order == 0

    async def test_shelf_book(self, db_session: AsyncSession):
        user = make_user()
        work = make_work()
        db_session.add_all([user, work])
        await db_session.flush()

        ub = UserBook(
            id=str(uuid.uuid4()),
            user_id=user.id,
            work_id=work.id,
            status="read",
        )
        shelf = Shelf(
            id=str(uuid.uuid4()),
            user_id=user.id,
            name="Sci-Fi",
            slug="sci-fi",
        )
        db_session.add_all([ub, shelf])
        await db_session.flush()

        sb = ShelfBook(
            shelf_id=shelf.id,
            user_book_id=ub.id,
            position=1,
        )
        db_session.add(sb)
        await db_session.flush()

        result = await db_session.execute(
            select(ShelfBook).where(
                ShelfBook.shelf_id == shelf.id,
                ShelfBook.user_book_id == ub.id,
            )
        )
        assert result.scalar_one().position == 1


# --- Social models ---


class TestSocial:
    async def test_follow(self, db_session: AsyncSession):
        user1 = make_user()
        user2 = make_user()
        db_session.add_all([user1, user2])
        await db_session.flush()

        follow = Follow(follower_id=user1.id, following_id=user2.id)
        db_session.add(follow)
        await db_session.flush()

        result = await db_session.execute(
            select(Follow).where(
                Follow.follower_id == user1.id,
                Follow.following_id == user2.id,
            )
        )
        assert result.scalar_one() is not None

    async def test_block(self, db_session: AsyncSession):
        user1 = make_user()
        user2 = make_user()
        db_session.add_all([user1, user2])
        await db_session.flush()

        block = Block(blocker_id=user1.id, blocked_id=user2.id)
        db_session.add(block)
        await db_session.flush()

        result = await db_session.execute(
            select(Block).where(Block.blocker_id == user1.id)
        )
        assert result.scalar_one().blocked_id == user2.id

    async def test_mute(self, db_session: AsyncSession):
        user1 = make_user()
        user2 = make_user()
        db_session.add_all([user1, user2])
        await db_session.flush()

        mute = Mute(muter_id=user1.id, muted_id=user2.id)
        db_session.add(mute)
        await db_session.flush()

        result = await db_session.execute(
            select(Mute).where(Mute.muter_id == user1.id)
        )
        assert result.scalar_one().muted_id == user2.id

    async def test_activity(self, db_session: AsyncSession):
        user = make_user()
        db_session.add(user)
        await db_session.flush()

        target_id = str(uuid.uuid4())
        activity = Activity(
            id=str(uuid.uuid4()),
            user_id=user.id,
            activity_type="finished_book",
            target_id=target_id,
            metadata_={"rating": 4.5},
        )
        db_session.add(activity)
        await db_session.flush()

        result = await db_session.get(Activity, activity.id)
        assert result.activity_type == "finished_book"
        assert result.metadata_["rating"] == 4.5


# --- TasteMatch model ---


class TestTasteMatch:
    async def test_create_taste_match(self, db_session: AsyncSession):
        user1 = make_user()
        user2 = make_user()
        db_session.add_all([user1, user2])
        await db_session.flush()

        tm = TasteMatch(
            user_a_id=user1.id,
            user_b_id=user2.id,
            match_score=Decimal("0.847"),
            overlapping_books_count=12,
            computed_at=datetime.now(timezone.utc),
        )
        db_session.add(tm)
        await db_session.flush()

        result = await db_session.execute(
            select(TasteMatch).where(
                TasteMatch.user_a_id == user1.id,
                TasteMatch.user_b_id == user2.id,
            )
        )
        match = result.scalar_one()
        assert match.match_score == Decimal("0.847")
        assert match.overlapping_books_count == 12
