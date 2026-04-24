"""
High-level entry point for the price intelligence engine.

Callers should only need this class. Internals (providers, rules) stay pluggable.
"""

from __future__ import annotations

import logging
from datetime import date
from typing import Optional

from models import (
    FlightOffer,
    PriceIntelligence,
    PriceLabel,
)

from . import rules
from .route_stats import RouteStatsProvider, RouteStats

logger = logging.getLogger(__name__)


class PriceIntelEngine:
    """
    Orchestrates: look up route stats → classify price → return PriceIntelligence.
    One engine instance is safe to reuse across requests.
    """

    def __init__(self, stats_provider: RouteStatsProvider):
        self._stats_provider = stats_provider

    def classify_offer(self, offer: FlightOffer, departure_date: date) -> PriceIntelligence:
        """Classify a single FlightOffer."""
        if not offer.itineraries:
            return _unknown("Offer has no itineraries.")

        first_seg = offer.itineraries[0].segments[0]
        origin = first_seg.origin
        destination = offer.itineraries[0].segments[-1].destination
        cabin = first_seg.cabin.value

        stats = self._stats_provider.get(origin, destination, cabin)
        if stats is None:
            return _unknown(
                f"Not enough price history yet for {origin} → {destination} ({cabin}). "
                "Classification will improve as we collect more observations."
            )

        days_out = max((departure_date - date.today()).days, 0)
        return rules.classify(offer.price.total_usd, stats, days_out)

    def classify_price(
        self,
        price_usd: float,
        origin: str,
        destination: str,
        cabin_class: str,
        departure_date: date,
    ) -> PriceIntelligence:
        """Classify a raw (price, route) — useful for the watch-check loop."""
        stats = self._stats_provider.get(origin, destination, cabin_class)
        if stats is None:
            return _unknown(
                f"Not enough price history yet for {origin} → {destination} ({cabin_class})."
            )
        days_out = max((departure_date - date.today()).days, 0)
        return rules.classify(price_usd, stats, days_out)

    def enrich_offers(
        self,
        offers: list[FlightOffer],
        departure_date: date,
    ) -> list[FlightOffer]:
        """Return a new list where each offer has its price_intelligence populated."""
        out: list[FlightOffer] = []
        for o in offers:
            pi = self.classify_offer(o, departure_date)
            out.append(o.model_copy(update={"price_intelligence": pi}))
        return out

    def get_route_stats(
        self, origin: str, destination: str, cabin_class: str
    ) -> Optional[RouteStats]:
        """Expose raw stats (useful for debugging and /watch/{id}/check responses)."""
        return self._stats_provider.get(origin, destination, cabin_class)


def _unknown(reason: str) -> PriceIntelligence:
    return PriceIntelligence(
        price_label=PriceLabel.UNKNOWN,
        action_reason=reason,
    )
