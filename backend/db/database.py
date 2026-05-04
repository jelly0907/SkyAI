"""
Async SQLAlchemy engine + session factory.

Keeping this file tiny so the prod swap (SQLite → Postgres) is genuinely
just a connection-string change plus driver install — no code edits.
"""

from __future__ import annotations

import os
from typing import AsyncGenerator

from sqlalchemy import event
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


# ── SQLite tuning ─────────────────────────────────────────────────────────────
# In rollback-journal mode (the default), any write takes an EXCLUSIVE lock
# on the database file and blocks every reader for the duration of the commit.
# That's exactly what was producing the "second search times out" symptom:
# search request #1 was still flushing 50 PriceObservation rows when request
# #2's DBRouteStatsProvider tried to read percentiles and hit the lock.
#
# Switching to WAL gives us "many concurrent readers + one writer" semantics,
# and busy_timeout=5000 tells SQLite to spin up to 5s rather than fail
# immediately if it ever does see contention. synchronous=NORMAL keeps the
# durability guarantees we need (no torn writes) while skipping the per-commit
# fsync of FULL — appropriate for a development/observability table.
if DATABASE_URL.startswith("sqlite"):
    @event.listens_for(engine.sync_engine, "connect")
    def _sqlite_tune(dbapi_conn, _record):  # noqa: ANN001
        cursor = dbapi_conn.cursor()
        try:
            cursor.execute("PRAGMA journal_mode=WAL")
            cursor.execute("PRAGMA busy_timeout=5000")
            cursor.execute("PRAGMA synchronous=NORMAL")
        finally:
            cursor.close()

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
