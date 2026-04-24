"""
SkyAI — Database layer.

Thin wrapper over SQLAlchemy async. Default backend is SQLite
(`sqlite+aiosqlite:///./skyai.db`) for zero-setup dev. Production sets
DATABASE_URL to a Postgres URL (see DEV_TO_PROD_MIGRATION.md).
"""

from .database import init_db, get_session, AsyncSessionLocal, engine
from .models_sql import Base, PriceObservation, PriceWatch, WatchTrigger

__all__ = [
    "init_db",
    "get_session",
    "AsyncSessionLocal",
    "engine",
    "Base",
    "PriceObservation",
    "PriceWatch",
    "WatchTrigger",
]
