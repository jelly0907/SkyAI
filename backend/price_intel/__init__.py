"""
SkyAI — Price Intelligence engine.

A pluggable, provider-agnostic module that turns a raw price + route into a
`PriceIntelligence` object (label, percentile, trend, action, explanation).

Today: rule-based classification over a RouteStatsProvider.
Tomorrow: swap MockRouteStatsProvider → DBRouteStatsProvider, then bolt on
XGBoost / Prophet without touching any caller.
"""

from .engine import PriceIntelEngine
from .route_stats import RouteStats, RouteStatsProvider, MockRouteStatsProvider

__all__ = [
    "PriceIntelEngine",
    "RouteStats",
    "RouteStatsProvider",
    "MockRouteStatsProvider",
]
