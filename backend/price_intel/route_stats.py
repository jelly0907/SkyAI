"""
Route statistics providers.

A `RouteStats` object is the input the classifier rules need. We support two
sources today:
  - MockRouteStatsProvider:  hard-coded ROUTE_DB (used when DB is empty / cold start)
  - DBRouteStatsProvider:    aggregates over logged price_observations

Production wiring uses FallbackRouteStatsProvider(DB → Mock) so freshly-deployed
or thinly-observed routes degrade to the mock baseline rather than UNKNOWN.

All providers are ASYNC (`async def get`) to match the rest of the backend.
"""

from __future__ import annotations

import asyncio
import logging
from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import async_sessionmaker, AsyncSession

logger = logging.getLogger(__name__)


@dataclass
class RouteStats:
    """
    Canonical shape the classifier consumes. Percentile fields are optional so
    Phase 1 providers can populate just min/median/max and let the classifier
    derive approximate p10/p25/p75/p90 itself.
    """
    origin: str
    destination: str
    cabin_class: str

    price_min: float
    price_median: float
    price_max: float

    # Optional percentile fields — filled by DB provider in Phase 2
    p10: Optional[float] = None
    p25: Optional[float] = None
    p75: Optional[float] = None
    p90: Optional[float] = None

    observation_count: int = 0
    last_updated: Optional[datetime] = None

    @property
    def has_percentiles(self) -> bool:
        return all(x is not None for x in (self.p10, self.p25, self.p75, self.p90))


class RouteStatsProvider(ABC):
    """Abstract source of RouteStats for a given route + cabin (async)."""

    @abstractmethod
    async def get(
        self,
        origin: str,
        destination: str,
        cabin_class: str,
    ) -> Optional[RouteStats]:
        """Return stats for (origin, destination, cabin), or None if unknown."""


# ── Mock provider — pure dict lookup, used as fallback when DB is empty ───────

class MockRouteStatsProvider(RouteStatsProvider):
    """
    Wraps mock_data.ROUTE_DB so the engine has a baseline before any
    observations have been collected. Route lookup is direction-agnostic
    (frozenset keys), matching mock_data.
    """

    def __init__(self, route_db: dict):
        self._route_db = route_db

    async def get(
        self,
        origin: str,
        destination: str,
        cabin_class: str,
    ) -> Optional[RouteStats]:
        key = frozenset({origin.upper(), destination.upper()})
        r = self._route_db.get(key)
        if not r:
            return None
        return RouteStats(
            origin=origin.upper(),
            destination=destination.upper(),
            cabin_class=cabin_class,
            price_min=float(r["price_min"]),
            price_median=float(r["price_median"]),
            price_max=float(r["price_max"]),
            observation_count=1_000,   # mock confidence baseline
        )


# ── DB provider — computes percentiles from logged price_observations ─────────

class DBRouteStatsProvider(RouteStatsProvider):
    """
    Computes RouteStats on the fly from logged price_observations using async
    SQLAlchemy. Returns None if fewer than MIN_OBS recent observations exist —
    the engine then falls back to the mock provider.

    Stats are direction-specific (SFO→JFK is treated as a different route than
    JFK→SFO) since prices and demand are not symmetric in the real world.

    A per-instance cache keeps the engine fast under repeated requests for
    popular routes; it expires after CACHE_TTL_SECONDS so newly-logged
    observations show up reasonably quickly.
    """
    MIN_OBS = 10                  # minimum sample size to trust the stats
    LOOKBACK_DAYS = 90            # ignore observations older than this
    CACHE_TTL_SECONDS = 300       # 5 min — balance freshness vs. DB load
    QUERY_TIMEOUT_SECONDS = 1.5   # bail out fast if the DB is slow/locked

    def __init__(self, session_factory: async_sessionmaker[AsyncSession]):
        self._session_factory = session_factory
        # (origin, destination, cabin) → (RouteStats|None, expires_at)
        self._cache: dict[tuple[str, str, str], tuple[Optional[RouteStats], datetime]] = {}

    async def get(
        self,
        origin: str,
        destination: str,
        cabin_class: str,
    ) -> Optional[RouteStats]:
        cache_key = (origin.upper(), destination.upper(), cabin_class)
        now = datetime.now(timezone.utc)

        cached = self._cache.get(cache_key)
        if cached and cached[1] > now:
            return cached[0]

        # Hard ceiling on how long we'll wait for the database. If a
        # concurrent writer is holding a lock and busy_timeout still hasn't
        # cleared, returning None lets the FallbackRouteStatsProvider
        # degrade to the mock baseline instead of hanging the request.
        try:
            stats = await asyncio.wait_for(
                self._compute_stats(origin, destination, cabin_class, now),
                timeout=self.QUERY_TIMEOUT_SECONDS,
            )
        except asyncio.TimeoutError:
            logger.warning(
                "DBRouteStatsProvider: query timed out for %s→%s (%s); "
                "degrading to fallback provider.",
                origin, destination, cabin_class,
            )
            # Short negative cache so we don't pile timeouts on top of each other.
            self._cache[cache_key] = (None, now + timedelta(seconds=30))
            return None

        if stats is None:
            # Cache the negative result too — saves repeated zero-row
            # queries on routes we have no data for. Shorter TTL so
            # we re-check soon as observations start coming in.
            self._cache[cache_key] = (None, now + timedelta(seconds=60))
            return None

        self._cache[cache_key] = (stats, now + timedelta(seconds=self.CACHE_TTL_SECONDS))
        return stats

    async def _compute_stats(
        self,
        origin: str,
        destination: str,
        cabin_class: str,
        now: datetime,
    ) -> Optional[RouteStats]:
        """Issue the actual query + percentile math. Split out so the public
        `get()` can wrap it in a timeout cleanly."""
        from db.models_sql import PriceObservation

        cutoff = now - timedelta(days=self.LOOKBACK_DAYS)

        async with self._session_factory() as sess:
            result = await sess.execute(
                select(PriceObservation.price_usd, PriceObservation.observed_at).where(
                    PriceObservation.origin == origin.upper(),
                    PriceObservation.destination == destination.upper(),
                    PriceObservation.cabin_class == cabin_class,
                    PriceObservation.observed_at >= cutoff,
                )
            )
            rows = result.all()

        prices = [float(r[0]) for r in rows]
        if len(prices) < self.MIN_OBS:
            return None

        prices.sort()
        n = len(prices)

        def pct(p: float) -> float:
            """Linear-interpolation percentile (matches numpy default)."""
            k = (n - 1) * p
            f = int(k)
            c = min(f + 1, n - 1)
            if f == c:
                return prices[f]
            return prices[f] + (prices[c] - prices[f]) * (k - f)

        last_observed = max((r[1] for r in rows), default=None)

        return RouteStats(
            origin=origin.upper(),
            destination=destination.upper(),
            cabin_class=cabin_class,
            price_min=float(prices[0]),
            price_median=float(pct(0.50)),
            price_max=float(prices[-1]),
            p10=float(pct(0.10)),
            p25=float(pct(0.25)),
            p75=float(pct(0.75)),
            p90=float(pct(0.90)),
            observation_count=n,
            last_updated=last_observed,
        )

    def invalidate_cache(self) -> None:
        """Drop all cached stats — useful for tests and admin endpoints."""
        self._cache.clear()


# ── Fallback chain — try each provider in order, first non-None wins ──────────

class FallbackRouteStatsProvider(RouteStatsProvider):
    """Try providers in order; first non-None wins."""

    def __init__(self, *providers: RouteStatsProvider):
        self._providers = providers

    async def get(
        self,
        origin: str,
        destination: str,
        cabin_class: str,
    ) -> Optional[RouteStats]:
        for p in self._providers:
            stats = await p.get(origin, destination, cabin_class)
            if stats is not None:
                return stats
        return None
