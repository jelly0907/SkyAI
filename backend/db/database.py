"""
Async SQLAlchemy engine + session factory.

Keeping this file tiny so the prod swap (SQLite → Postgres) is genuinely
just a connection-string change plus driver install — no code edits.
"""

from __future__ import annotations

import os
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

# Default: local SQLite file in the backend working directory.
# Override in prod: DATABASE_URL=postgresql+asyncpg://user:pw@host/skyai
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "sqlite+aiosqlite:///./skyai.db",
)

# SQLite needs check_same_thread=False when used with async; Postgres ignores it.
_connect_args: dict = {}
if DATABASE_URL.startswith("sqlite"):
    _connect_args["check_same_thread"] = False

engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    future=True,
    connect_args=_connect_args,
    # Pool tuning is ignored by SQLite; will take effect on Postgres.
    pool_pre_ping=True,
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)


async def init_db() -> None:
    """
    Create tables if they don't exist. For dev only — production must use
    Alembic migrations (see DEV_TO_PROD_MIGRATION.md).
    """
    from .models_sql import Base  # local import to avoid circulars

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency — yields a session per request."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
