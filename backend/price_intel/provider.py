"""
Singleton wiring for the PriceIntelEngine used across routes.

Kept small and side-effect-free on import. The engine itself is stateless;
the expensive part (stats computation) is behind the RouteStatsProvider.
"""

from __future__ import annotations

from functools import lru_cache

from .engine import PriceIntelEngine
from .route_stats import MockRouteStatsProvider


@lru_cache(maxsize=1)
def get_price_intel_engine() -> PriceIntelEngine:
    """
    Phase 1: stats come from mock_data.ROUTE_DB.
    Phase 2: wrap MockRouteStatsProvider in FallbackRouteStatsProvider that
    tries DBRouteStatsProvider first, falls back to mock when observations
    are thin.
    """
    # Late import to keep price_intel import-cheap.
    from mock_data import ROUTE_DB
    provider = MockRouteStatsProvider(ROUTE_DB)
    return PriceIntelEngine(provider)
