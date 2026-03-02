import uuid
from datetime import date, datetime, timezone
from decimal import Decimal

import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from models import (
    Activity,
    ActivityType,
    Author,
    Block,
    Edition,
    EditionFormat,
    Follow,
    Mute,
    ReadingStatus,
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
        "id": uuid.uuid4(),
        "username": f"user_{uuid.uuid4().hex[:8]}",
    }
    defaults.update(kwargs)
    return User(**defaults)


def make_work(**kwargs) -> Work:
    defaults = {
        "id": uuid.uuid4(),
        "title": "Test Book",
    }
    defaults.update(kwargs)
    return Work(**defaults)


# --- Work model ---


class TestWork:
    async def test_create_work(self, session: AsyncSession):
        work = make_work(title="Dune", first_published_year=1965)
        session.add(work)
        await session.flush()

        result = await session.get(Work, work.id)
        assert result is not None
        assert result.title == "Dune"
        assert result.first_published_year == 1965

    async def test_work_with_subjects(self, session: AsyncSession):
        work = make_work(subjects=["fiction", "sci-fi"])
        session.add(work)
        await session.flush()

        result = await session.get(Work, work.id)
        assert result.subjects == ["fiction", "sci-fi"]

    async def test_work_defaults(self, session: AsyncSession):
        work = make_work()
        session.add(work)
        await session.flush()

        result = await session.get(Work, work.id)
        assert result.ratings_count == 0
        assert result.average_rating is None


# --- Author model ---


class TestAuthor:
    async def test_create_author(self, session: AsyncSession):
        author = Author(id=uuid.uuid4(), name="Frank Herbert")
        session.add(author)
        await session.flush()

        result = await session.get(Author, author.id)
        assert result.name == "Frank Herbert"

    async def test_work_author_relationship(self, session: AsyncSession):
        author = Author(id=uuid.uuid4(), name="Tolkien")
        work = make_work(title="The Hobbit")
        work.authors.append(author)
        session.add(work)
        await session.flush()

        result = await session.get(Work, work.id)
        assert len(result.authors) == 1
        assert result.authors[0].name == "Tolkien"


# --- Edition model ---


class TestEdition:
    async def test_create_edition(self, session: AsyncSession):
        work = make_work()
        session.add(work)
        await session.flush()

        edition = Edition(
            id=uuid.uuid4(),
            work_id=work.id,
            isbn_13="9780441013593",
            publisher="Ace Books",
            format=EditionFormat.PAPERBACK,
            page_count=688,
        )
        session.add(edition)
        await session.flush()

        result = await session.get(Edition, edition.id)
        assert result.isbn_13 == "9780441013593"
        assert result.format == EditionFormat.PAPERBACK


# --- User model ---


class TestUser:
    async def test_create_user(self, session: AsyncSession):
        user = make_user(username="bookworm", display_name="Book Worm")
        session.add(user)
        await session.flush()

        result = await session.get(User, user.id)
        assert result.username == "bookworm"
        assert result.display_name == "Book Worm"
        assert result.is_premium is False

    async def test_unique_username(self, session: AsyncSession):
        user1 = make_user(username="unique_name")
        user2 = make_user(username="unique_name")
        session.add(user1)
        await session.flush()
        session.add(user2)
        with pytest.raises(IntegrityError):
            await session.flush()
        await session.rollback()

    async def test_soft_delete(self, session: AsyncSession):
        user = make_user()
        session.add(user)
        await session.flush()

        user.deleted_at = datetime.now(timezone.utc)
        await session.flush()

        result = await session.get(User, user.id)
        assert result.deleted_at is not None


# --- UserBook model ---


class TestUserBook:
    async def test_create_user_book(self, session: AsyncSession):
        user = make_user()
        work = make_work()
        session.add_all([user, work])
        await session.flush()

        ub = UserBook(
            id=uuid.uuid4(),
            user_id=user.id,
            work_id=work.id,
            status=ReadingStatus.READ,
            rating=Decimal("4.5"),
            review_text="Great book!",
        )
        session.add(ub)
        await session.flush()

        result = await session.get(UserBook, ub.id)
        assert result.status == ReadingStatus.READ
        assert result.rating == Decimal("4.5")
        assert result.is_imported is False

    async def test_user_book_unique_constraint(self, session: AsyncSession):
        user = make_user()
        work = make_work()
        session.add_all([user, work])
        await session.flush()

        ub1 = UserBook(
            id=uuid.uuid4(),
            user_id=user.id,
            work_id=work.id,
            status=ReadingStatus.READ,
        )
        ub2 = UserBook(
            id=uuid.uuid4(),
            user_id=user.id,
            work_id=work.id,
            status=ReadingStatus.WANT_TO_READ,
        )
        session.add(ub1)
        await session.flush()
        session.add(ub2)
        with pytest.raises(IntegrityError):
            await session.flush()
        await session.rollback()

    async def test_imported_book(self, session: AsyncSession):
        user = make_user()
        work = make_work()
        session.add_all([user, work])
        await session.flush()

        ub = UserBook(
            id=uuid.uuid4(),
            user_id=user.id,
            work_id=work.id,
            status=ReadingStatus.READ,
            rating=Decimal("3.0"),
            is_imported=True,
        )
        session.add(ub)
        await session.flush()

        result = await session.get(UserBook, ub.id)
        assert result.is_imported is True


# --- Shelf model ---


class TestShelf:
    async def test_create_shelf(self, session: AsyncSession):
        user = make_user()
        session.add(user)
        await session.flush()

        shelf = Shelf(
            id=uuid.uuid4(),
            user_id=user.id,
            name="Favorites",
            slug="favorites",
        )
        session.add(shelf)
        await session.flush()

        result = await session.get(Shelf, shelf.id)
        assert result.name == "Favorites"
        assert result.is_public is True
        assert result.display_order == 0

    async def test_shelf_book(self, session: AsyncSession):
        user = make_user()
        work = make_work()
        session.add_all([user, work])
        await session.flush()

        ub = UserBook(
            id=uuid.uuid4(),
            user_id=user.id,
            work_id=work.id,
            status=ReadingStatus.READ,
        )
        shelf = Shelf(
            id=uuid.uuid4(),
            user_id=user.id,
            name="Sci-Fi",
            slug="sci-fi",
        )
        session.add_all([ub, shelf])
        await session.flush()

        sb = ShelfBook(
            id=uuid.uuid4(),
            shelf_id=shelf.id,
            user_book_id=ub.id,
            position=1,
        )
        session.add(sb)
        await session.flush()

        result = await session.get(ShelfBook, sb.id)
        assert result.position == 1


# --- Social models ---


class TestSocial:
    async def test_follow(self, session: AsyncSession):
        user1 = make_user()
        user2 = make_user()
        session.add_all([user1, user2])
        await session.flush()

        follow = Follow(follower_id=user1.id, following_id=user2.id)
        session.add(follow)
        await session.flush()

        result = await session.execute(
            select(Follow).where(
                Follow.follower_id == user1.id,
                Follow.following_id == user2.id,
            )
        )
        assert result.scalar_one() is not None

    async def test_block(self, session: AsyncSession):
        user1 = make_user()
        user2 = make_user()
        session.add_all([user1, user2])
        await session.flush()

        block = Block(blocker_id=user1.id, blocked_id=user2.id)
        session.add(block)
        await session.flush()

        result = await session.execute(
            select(Block).where(Block.blocker_id == user1.id)
        )
        assert result.scalar_one().blocked_id == user2.id

    async def test_mute(self, session: AsyncSession):
        user1 = make_user()
        user2 = make_user()
        session.add_all([user1, user2])
        await session.flush()

        mute = Mute(muter_id=user1.id, muted_id=user2.id)
        session.add(mute)
        await session.flush()

        result = await session.execute(
            select(Mute).where(Mute.muter_id == user1.id)
        )
        assert result.scalar_one().muted_id == user2.id

    async def test_activity(self, session: AsyncSession):
        user = make_user()
        session.add(user)
        await session.flush()

        target_id = uuid.uuid4()
        activity = Activity(
            id=uuid.uuid4(),
            user_id=user.id,
            activity_type=ActivityType.FINISHED_BOOK,
            target_id=target_id,
            metadata_={"rating": 4.5},
        )
        session.add(activity)
        await session.flush()

        result = await session.get(Activity, activity.id)
        assert result.activity_type == ActivityType.FINISHED_BOOK
        assert result.metadata_["rating"] == 4.5


# --- TasteMatch model ---


class TestTasteMatch:
    async def test_create_taste_match(self, session: AsyncSession):
        user1 = make_user()
        user2 = make_user()
        session.add_all([user1, user2])
        await session.flush()

        tm = TasteMatch(
            user_a_id=user1.id,
            user_b_id=user2.id,
            match_score=Decimal("0.847"),
            overlapping_books_count=12,
            computed_at=datetime.now(timezone.utc),
        )
        session.add(tm)
        await session.flush()

        result = await session.execute(
            select(TasteMatch).where(
                TasteMatch.user_a_id == user1.id,
                TasteMatch.user_b_id == user2.id,
            )
        )
        match = result.scalar_one()
        assert match.match_score == Decimal("0.847")
        assert match.overlapping_books_count == 12
