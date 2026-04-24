"""
Route statistics providers.

A `RouteStats` object is the input that the classifier rules need. Today we
supply stats from the mock ROUTE_DB; in Phase 2 we'll supply them from
TimescaleDB aggregates over logged price_observations.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime
from typing import Optional


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
    """Abstract source of RouteStats for a given route + cabin."""

    @abstractmethod
    def get(
        self,
        origin: str,
        destination: str,
        cabin_class: str,
    ) -> Optional[RouteStats]:
        """Return stats for (origin, destination, cabin), or None if unknown."""


# ── Mock provider (Phase 1) ───────────────────────────────────────────────────

class MockRouteStatsProvider(RouteStatsProvider):
    """
    Wraps mock_data.ROUTE_DB so the engine works today without any database.
    Route lookup is direction-agnostic (frozenset keys), matching mock_data.
    """

    def __init__(self, route_db: dict):
        self._route_db = route_db

    def get(
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


# ── DB provider (Phase 2 stub) ────────────────────────────────────────────────

class DBRouteStatsProvider(RouteStatsProvider):
    """
    Computes RouteStats on the fly from logged price_observations in SQLite.
    Returns None if fewer than MIN_OBS observations exist for the route — in
    that case the engine should fall back to the mock provider.
    """
    MIN_OBS = 20

    def __init__(self, session_factory):
        self._session_factory = session_factory

    def get(
        self,
        origin: str,
        destination: str,
        cabin_class: str,
    ) -> Optional[RouteStats]:
        from sqlalchemy import select, func
        from db.models_sql import PriceObservation

        with self._session_factory() as sess:
            base = select(PriceObservation.price_usd).where(
                PriceObservation.origin == origin.upper(),
                PriceObservation.destination == destination.upper(),
                PriceObservation.cabin_class == cabin_class,
            )
            prices = [row[0] for row in sess.execute(base).all()]

            if len(prices) < self.MIN_OBS:
                return None

            prices.sort()
            n = len(prices)

            def pct(p: float) -> float:
                # linear interpolation
                k = (n - 1) * p
                f = int(k)
                c = min(f + 1, n - 1)
                if f == c:
                    return prices[f]
                return prices[f] + (prices[c] - prices[f]) * (k - f)

            last_updated = sess.execute(
                select(func.max(PriceObservation.observed_at)).where(
                    PriceObservation.origin == origin.upper(),
                    PriceObservation.destination == destination.upper(),
                    PriceObservation.cabin_class == cabin_class,
                )
            ).scalar_one_or_none()

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
                last_updated=last_updated,
            )


class FallbackRouteStatsProvider(RouteStatsProvider):
    """Try providers in order; first non-None wins."""

    def __init__(self, *providers: RouteStatsProvider):
        self._providers = providers

    def get(
        self,
        origin: str,
        destination: str,
        cabin_class: str,
    ) -> Optional[RouteStats]:
        for p in self._providers:
            stats = p.get(origin, destination, cabin_class)
            if stats is not None:
                return stats
        return None
