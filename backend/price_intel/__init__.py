"""
SkyAI — Price Intelligence engine.

A pluggable, provider-agnostic module that turns a raw price + route into a
`PriceIntelligence` object (label, percentile, trend, action, explanation).

Today: rule-based classification over a RouteStatsProvider chain
       (DB observations → mock baselines).
Tomorrow: bolt on XGBoost / Prophet without touching any caller — just
          implement RouteStatsProvider.get() with the new model.
"""

from .engine import PriceIntelEngine
from .route_stats import (
    DBRouteStatsProvider,
    FallbackRouteStatsProvider,
    MockRouteStatsProvider,
    RouteStats,
    RouteStatsProvider,
)

__all__ = [
    "PriceIntelEngine",
    "RouteStats",
    "RouteStatsProvider",
    "MockRouteStatsProvider",
    "DBRouteStatsProvider",
    "FallbackRouteStatsProvider",
]
