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
