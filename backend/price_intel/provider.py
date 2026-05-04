"""
Singleton wiring for the PriceIntelEngine used across routes.

Kept small and side-effect-free on import. The engine itself is stateless;
the expensive part (stats computation) is behind the RouteStatsProvider.

Provider chain (first non-None wins):
  1. DBRouteStatsProvider   — real percentiles from logged price_observations
  2. MockRouteStatsProvider — hard-coded baselines, used when the DB has
                              fewer than MIN_OBS observations for a route

This means: cold-start routes still get a useful classification (via mock),
and as observations accumulate, the engine seamlessly transitions to using
real data without any code changes.
"""

from __future__ import annotations

import logging
from functools import lru_cache

from .engine import PriceIntelEngine
from .route_stats import (
    DBRouteStatsProvider,
    FallbackRouteStatsProvider,
    MockRouteStatsProvider,
)

logger = logging.getLogger(__name__)


@lru_cache(maxsize=1)
def get_price_intel_engine() -> PriceIntelEngine:
    # Late imports to keep price_intel import-cheap and avoid pulling
    # SQLAlchemy into modules that don't need it.
    from db.database import AsyncSessionLocal
    from mock_data import ROUTE_DB

    db_provider = DBRouteStatsProvider(AsyncSessionLocal)
    mock_provider = MockRouteStatsProvider(ROUTE_DB)
    chain = FallbackRouteStatsProvider(db_provider, mock_provider)
    logger.info("PriceIntel: DB→Mock chain wired")
    return PriceIntelEngine(chain)
