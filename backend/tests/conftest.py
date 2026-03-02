# LIMITATION: Tests use SQLite in-memory instead of Postgres. This means:
#   - Full-text search (tsvector) is approximated with ILIKE
#   - Trigram fuzzy matching (pg_trgm) is not tested
#   - ARRAY and JSONB columns are replaced with JSON
#   - UUID columns use String(36) with a TypeDecorator shim
# For full integration confidence, run tests against a real Postgres instance
# (e.g. via testcontainers-python or a local Docker Postgres).

import os
import sqlite3
import uuid

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

# Must set before importing model_stubs
os.environ["TESTING"] = "1"

# Register UUID adapter for SQLite so uuid.UUID objects auto-convert to strings
sqlite3.register_adapter(uuid.UUID, str)

from backend.api.model_stubs import (  # noqa: E402
    Author,
    Base,
    Edition,
    User,
    UserBook,
    Work,
)


@pytest.fixture
async def db_engine():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


@pytest.fixture
async def db_session(db_engine):
    session_factory = async_sessionmaker(db_engine, class_=AsyncSession, expire_on_commit=False)
    async with session_factory() as session:
        yield session


@pytest.fixture
def test_user_id():
    # Return string UUID for SQLite compatibility in test mode
    return str(uuid.uuid4())


@pytest.fixture
async def test_user(db_session, test_user_id):
    user = User(
        id=str(test_user_id),
        username="testuser",
        display_name="Test User",
        is_premium=False,
        is_deleted=False,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
async def test_work(db_session):
    work = Work(
        id=str(uuid.uuid4()),
        title="Test Book",
        first_published_year=2020,
        ratings_count=0,
    )
    db_session.add(work)
    await db_session.commit()
    await db_session.refresh(work)
    return work


@pytest.fixture
async def test_author(db_session):
    author = Author(
        id=str(uuid.uuid4()),
        name="Test Author",
    )
    db_session.add(author)
    await db_session.commit()
    await db_session.refresh(author)
    return author


@pytest.fixture
async def test_edition(db_session, test_work):
    edition = Edition(
        id=str(uuid.uuid4()),
        work_id=test_work.id,
        isbn_13="9780143127741",
        isbn_10="0143127748",
    )
    db_session.add(edition)
    await db_session.commit()
    await db_session.refresh(edition)
    return edition


@pytest.fixture
async def other_user(db_session):
    user = User(
        id=str(uuid.uuid4()),
        username="otheruser",
        display_name="Other User",
        is_premium=False,
        is_deleted=False,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
async def client(db_session, test_user_id, test_user):
    """HTTP test client with auth and DB overrides."""
    from backend.api.database import get_db
    from backend.api.deps import get_current_user, get_current_user_id
    from backend.api.main import create_app

    app = create_app()

    async def override_get_db():
        yield db_session

    async def override_get_current_user_id():
        return test_user_id

    async def override_get_current_user():
        return test_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user_id] = override_get_current_user_id
    app.dependency_overrides[get_current_user] = override_get_current_user

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


# --- Convenience aliases used by test files ---


@pytest.fixture
def auth_headers():
    """No-op headers — the client fixture already has auth overridden."""
    return {}


@pytest.fixture
def work_id(test_work):
    return test_work.id


@pytest.fixture
def user_id(test_user):
    return test_user.id


@pytest.fixture
def other_user_id(other_user):
    return other_user.id


@pytest.fixture
async def other_client(db_session, other_user):
    """HTTP test client authenticated as other_user."""
    from backend.api.database import get_db
    from backend.api.deps import get_current_user, get_current_user_id
    from backend.api.main import create_app

    app = create_app()

    async def override_get_db():
        yield db_session

    async def override_get_current_user_id():
        return other_user.id

    async def override_get_current_user():
        return other_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user_id] = override_get_current_user_id
    app.dependency_overrides[get_current_user] = override_get_current_user

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
async def client_as(db_session):
    """Factory fixture: creates clients authenticated as a given user.

    Usage: client = await client_as(some_user)
    """
    from backend.api.database import get_db
    from backend.api.deps import get_current_user, get_current_user_id
    from backend.api.main import create_app

    clients = []

    async def _make_client(user):
        app = create_app()

        async def override_get_db():
            yield db_session

        async def override_get_current_user_id():
            return user.id

        async def override_get_current_user():
            return user

        app.dependency_overrides[get_db] = override_get_db
        app.dependency_overrides[get_current_user_id] = override_get_current_user_id
        app.dependency_overrides[get_current_user] = override_get_current_user

        transport = ASGITransport(app=app)
        ac = AsyncClient(transport=transport, base_url="http://test")
        clients.append(ac)
        return ac

    yield _make_client

    for ac in clients:
        await ac.aclose()


@pytest.fixture
async def hidden_stats_user(db_session):
    """User with hide_reading_stats=True."""
    user = User(
        id=str(uuid.uuid4()),
        username="hiddenuser",
        display_name="Hidden Stats User",
        is_premium=False,
        is_deleted=False,
        hide_reading_stats=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
async def user_2(db_session):
    """Second additional test user."""
    user = User(
        id=str(uuid.uuid4()),
        username="user2",
        display_name="User Two",
        is_premium=False,
        is_deleted=False,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
async def user_3(db_session):
    """Third additional test user."""
    user = User(
        id=str(uuid.uuid4()),
        username="user3",
        display_name="User Three",
        is_premium=False,
        is_deleted=False,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
async def logged_books(db_session, test_user, test_work):
    """Create a finished book for test_user to produce meaningful stats."""
    from datetime import datetime

    ub = UserBook(
        id=str(uuid.uuid4()),
        user_id=test_user.id,
        work_id=test_work.id,
        status="read",
        rating=4.0,
        review_text="Great book!",
        has_spoilers=False,
        is_imported=False,
        is_hidden=False,
        is_private=False,
        finished_at=datetime.now(),
    )
    db_session.add(ub)
    await db_session.commit()
    return ub
