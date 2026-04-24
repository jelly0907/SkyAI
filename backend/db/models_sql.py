"""
SQLAlchemy ORM models.

All timestamps are timezone-aware. All IATA codes are stored uppercase.
Indexes and types are chosen for Postgres semantics so the prod swap is
seamless.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _new_id() -> str:
    return str(uuid.uuid4())


class Base(DeclarativeBase):
    """Shared declarative base."""


# ── Price history ─────────────────────────────────────────────────────────────

class PriceObservation(Base):
    """
    One price point observed for a specific flight offer. Populated after every
    successful /search/flights call. In Phase 2 this is what ML models train on
    and what DBRouteStatsProvider aggregates over.
    """
    __tablename__ = "price_observations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    observed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utc_now, nullable=False
    )

    origin: Mapped[str] = mapped_column(String(3), nullable=False)
    destination: Mapped[str] = mapped_column(String(3), nullable=False)
    departure_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    return_date: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))

    airline: Mapped[Optional[str]] = mapped_column(String(3))
    flight_number: Mapped[Optional[str]] = mapped_column(String(8))
    cabin_class: Mapped[str] = mapped_column(String(16), nullable=False)

    price_usd: Mapped[float] = mapped_column(Float, nullable=False)
    stops: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_duration_minutes: Mapped[Optional[int]] = mapped_column(Integer)

    source: Mapped[str] = mapped_column(String(32), nullable=False)   # "mock" | "amadeus" | ...
    price_label: Mapped[Optional[str]] = mapped_column(String(16))    # STEAL / GREAT_DEAL / …
    seats_remaining: Mapped[Optional[int]] = mapped_column(Integer)

    __table_args__ = (
        Index(
            "ix_obs_route_cabin_time",
            "origin", "destination", "cabin_class", "observed_at",
        ),
        Index("ix_obs_airline_dep", "airline", "departure_date"),
        CheckConstraint("price_usd >= 0", name="ck_obs_price_nonneg"),
    )


# ── Watches ───────────────────────────────────────────────────────────────────

class PriceWatch(Base):
    """A user-created alert for a specific route + dates + cabin."""
    __tablename__ = "price_watches"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_new_id)
    user_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)

    origin: Mapped[str] = mapped_column(String(3), nullable=False)
    destination: Mapped[str] = mapped_column(String(3), nullable=False)
    departure_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    return_date: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    cabin_class: Mapped[str] = mapped_column(String(16), nullable=False, default="ECONOMY")
    adults: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    max_stops: Mapped[Optional[int]] = mapped_column(Integer)

    target_price_usd: Mapped[Optional[float]] = mapped_column(Float)
    notify_on_great_deal: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utc_now, nullable=False
    )
    last_checked_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    last_price_usd: Mapped[Optional[float]] = mapped_column(Float)
    last_label: Mapped[Optional[str]] = mapped_column(String(16))
    triggered_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    trigger_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    triggers: Mapped[list["WatchTrigger"]] = relationship(
        back_populates="watch",
        cascade="all, delete-orphan",
        lazy="selectin",
    )

    __table_args__ = (
        Index("ix_watch_user_active", "user_id", "active"),
        Index("ix_watch_route_dep", "origin", "destination", "departure_date"),
        CheckConstraint(
            "target_price_usd IS NULL OR target_price_usd >= 0",
            name="ck_watch_target_nonneg",
        ),
    )


class WatchTrigger(Base):
    """Audit log of every time a watch fires."""
    __tablename__ = "watch_triggers"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    watch_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("price_watches.id", ondelete="CASCADE"), nullable=False
    )
    triggered_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_utc_now, nullable=False
    )
    price_usd: Mapped[float] = mapped_column(Float, nullable=False)
    price_label: Mapped[Optional[str]] = mapped_column(String(16))
    reason: Mapped[str] = mapped_column(Text, nullable=False)

    watch: Mapped[PriceWatch] = relationship(back_populates="triggers")

    __table_args__ = (
        Index("ix_trigger_watch_time", "watch_id", "triggered_at"),
    )
