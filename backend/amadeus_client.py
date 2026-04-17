"""
SkyAI — Amadeus API Client

Handles:
  - OAuth2 client-credentials token management (auto-refresh)
  - Flight Offers Search (v2)
  - Response normalization → SkyAI FlightOffer schema
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Optional

import httpx
from cachetools import TTLCache

from models import (
    BaggageInfo, CabinClass, FareConditions, FlightOffer, Itinerary,
    PriceBreakdown, PriceIntelligence, PriceLabel, SearchRequest, Segment,
)

logger = logging.getLogger(__name__)

# ── Constants ─────────────────────────────────────────────────────────────────

AMADEUS_TEST_BASE = "https://test.api.amadeus.com"
AMADEUS_PROD_BASE = "https://api.amadeus.com"

CABIN_MAP = {
    "ECONOMY": CabinClass.ECONOMY,
    "PREMIUM_ECONOMY": CabinClass.PREMIUM_ECONOMY,
    "BUSINESS": CabinClass.BUSINESS,
    "FIRST": CabinClass.FIRST,
}


# ── Token Manager ─────────────────────────────────────────────────────────────

class AmadeusTokenManager:
    """
    Manages Amadeus OAuth2 bearer tokens with automatic expiry handling.
    Tokens are cached for (expires_in - 60) seconds to avoid edge cases.
    """

    def __init__(self, client_id: str, client_secret: str, base_url: str):
        self._client_id = client_id
        self._client_secret = client_secret
        self._base_url = base_url
        self._token: Optional[str] = None
        self._token_expires_at: Optional[datetime] = None

    def _is_expired(self) -> bool:
        if self._token is None or self._token_expires_at is None:
            return True
        return datetime.now(timezone.utc) >= self._token_expires_at

    async def get_token(self, client: httpx.AsyncClient) -> str:
        if self._is_expired():
            await self._refresh(client)
        return self._token  # type: ignore

    async def _refresh(self, client: httpx.AsyncClient) -> None:
        logger.info("Refreshing Amadeus access token...")
        resp = await client.post(
            f"{self._base_url}/v1/security/oauth2/token",
            data={
                "grant_type": "client_credentials",
                "client_id": self._client_id,
                "client_secret": self._client_secret,
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=10.0,
        )
        resp.raise_for_status()
        data = resp.json()

        self._token = data["access_token"]
        expires_in: int = data.get("expires_in", 1799)

        from datetime import timedelta
        self._token_expires_at = datetime.now(timezone.utc) + timedelta(seconds=expires_in - 60)
        logger.info(f"Amadeus token refreshed. Expires in {expires_in}s.")


# ── Main Client ───────────────────────────────────────────────────────────────

class AmadeusClient:
    """
    Async Amadeus API client. Instantiate once and share across requests.
    Uses a shared httpx.AsyncClient with connection pooling.
    """

    def __init__(self, client_id: str, client_secret: str, env: str = "test"):
        self._base_url = AMADEUS_PROD_BASE if env == "production" else AMADEUS_TEST_BASE
        self._token_manager = AmadeusTokenManager(client_id, client_secret, self._base_url)
        self._http: Optional[httpx.AsyncClient] = None

        # Simple in-memory cache: key = (origin, dest, date, cabin, adults), TTL = 15 min
        self._cache: TTLCache = TTLCache(maxsize=256, ttl=900)

    async def start(self) -> None:
        """Call on app startup to initialize the HTTP connection pool."""
        self._http = httpx.AsyncClient(timeout=httpx.Timeout(15.0), http2=True)

    async def stop(self) -> None:
        """Call on app shutdown to release connections."""
        if self._http:
            await self._http.aclose()

    # ── Public Methods ────────────────────────────────────────────────────────

    async def search_flights(self, req: SearchRequest) -> list[FlightOffer]:
        """
        Search for flight offers using Amadeus Flight Offers Search v2.
        Results are cached for 15 minutes per unique search key.
        """
        cache_key = (
            req.origin, req.destination,
            req.departure_date.isoformat(),
            req.return_date.isoformat() if req.return_date else "",
            req.cabin_class.value,
            req.adults, req.children, req.infants,
            req.non_stop_only,
        )

        if cache_key in self._cache:
            logger.info(f"Cache hit for {req.origin}→{req.destination}")
            return self._cache[cache_key]

        raw = await self._fetch_offers(req)
        offers = [self._normalize_offer(o, req) for o in raw]

        # Sort: price ascending (baseline — Comparison Agent will re-rank with ML)
        offers.sort(key=lambda o: o.price.total_usd)

        self._cache[cache_key] = offers
        return offers

    # ── Private: Fetch ────────────────────────────────────────────────────────

    async def _fetch_offers(self, req: SearchRequest) -> list[dict]:
        assert self._http is not None, "Client not started. Call start() first."

        token = await self._token_manager.get_token(self._http)

        params: dict = {
            "originLocationCode": req.origin.upper(),
            "destinationLocationCode": req.destination.upper(),
            "departureDate": req.departure_date.isoformat(),
            "adults": req.adults,
            "max": req.max_results,
            "currencyCode": "USD",
        }

        if req.children > 0:
            params["children"] = req.children
        if req.infants > 0:
            params["infants"] = req.infants
        if req.return_date:
            params["returnDate"] = req.return_date.isoformat()
        if req.non_stop_only:
            params["nonStop"] = "true"
        if req.cabin_class != CabinClass.ECONOMY:
            params["travelClass"] = req.cabin_class.value

        logger.info(f"Calling Amadeus: {req.origin}→{req.destination} on {req.departure_date}")

        resp = await self._http.get(
            f"{self._base_url}/v2/shopping/flight-offers",
            params=params,
            headers={"Authorization": f"Bearer {token}"},
        )

        if resp.status_code == 401:
            # Token expired mid-request; force refresh and retry once
            logger.warning("Amadeus 401 — forcing token refresh and retrying.")
            self._token_manager._token = None
            token = await self._token_manager.get_token(self._http)
            resp = await self._http.get(
                f"{self._base_url}/v2/shopping/flight-offers",
                params=params,
                headers={"Authorization": f"Bearer {token}"},
            )

        resp.raise_for_status()
        data = resp.json()
        return data.get("data", [])

    # ── Private: Normalize ────────────────────────────────────────────────────

    def _normalize_offer(self, raw: dict, req: SearchRequest) -> FlightOffer:
        """Convert Amadeus raw offer dict → SkyAI FlightOffer schema."""

        itineraries = [self._parse_itinerary(it) for it in raw.get("itineraries", [])]

        # Price
        price_data = raw.get("price", {})
        total = float(price_data.get("grandTotal", price_data.get("total", 0)))
        base = float(price_data.get("base", 0))
        taxes = round(total - base, 2)

        per_adult = None
        traveler_pricings = raw.get("travelerPricings", [])
        if traveler_pricings:
            per_adult = float(traveler_pricings[0].get("price", {}).get("total", total))

        price = PriceBreakdown(
            total_usd=total,
            base_fare_usd=base,
            taxes_usd=taxes,
            per_adult_usd=per_adult,
        )

        # Baggage (from first traveler pricing, first segment)
        baggage = self._parse_baggage(traveler_pricings)

        # Fare conditions
        fare_conditions = self._parse_fare_conditions(traveler_pricings)

        # Seats remaining
        seats_remaining = raw.get("numberOfBookableSeats")

        # Price intelligence (Phase 1: rule-based percentile placeholder)
        # Will be replaced by XGBoost in Phase 2
        price_intel = self._basic_price_intel(total, req)

        # Booking URL — deep link to Amadeus booking page
        # In production, integrate Amadeus Flight Create Order API
        booking_url = None

        return FlightOffer(
            offer_id=raw.get("id", str(uuid.uuid4())),
            source="amadeus",
            itineraries=itineraries,
            price=price,
            baggage=baggage,
            fare_conditions=fare_conditions,
            seats_remaining=seats_remaining,
            price_intelligence=price_intel,
            booking_url=booking_url,
            last_ticketing_date=raw.get("lastTicketingDate"),
        )

    def _parse_itinerary(self, raw_it: dict) -> Itinerary:
        segments = []
        for seg in raw_it.get("segments", []):
            departure = seg.get("departure", {})
            arrival = seg.get("arrival", {})

            dep_dt = datetime.fromisoformat(departure.get("at", ""))
            arr_dt = datetime.fromisoformat(arrival.get("at", ""))
            duration_min = int((arr_dt - dep_dt).total_seconds() / 60)

            cabin_raw = ""
            if seg.get("cabin"):
                cabin_raw = seg["cabin"]
            cabin = CABIN_MAP.get(cabin_raw, CabinClass.ECONOMY)

            segments.append(Segment(
                origin=departure.get("iataCode", ""),
                destination=arrival.get("iataCode", ""),
                departure_at=dep_dt,
                arrival_at=arr_dt,
                carrier_code=seg.get("carrierCode", ""),
                flight_number=str(seg.get("number", "")),
                aircraft_code=seg.get("aircraft", {}).get("code"),
                duration_minutes=duration_min,
                cabin=cabin,
            ))

        total_duration_min = self._parse_iso_duration(raw_it.get("duration", "PT0M"))
        stops = len(segments) - 1

        return Itinerary(
            segments=segments,
            total_duration_minutes=total_duration_min,
            stops=stops,
        )

    @staticmethod
    def _parse_iso_duration(duration_str: str) -> int:
        """Parse ISO 8601 duration (e.g. 'PT9H55M') → minutes."""
        import re
        hours = int((re.search(r"(\d+)H", duration_str) or type("", (), {"group": lambda s, x: 0})()).group(1) or 0)
        mins = int((re.search(r"(\d+)M", duration_str) or type("", (), {"group": lambda s, x: 0})()).group(1) or 0)
        return hours * 60 + mins

    @staticmethod
    def _parse_baggage(traveler_pricings: list[dict]) -> BaggageInfo:
        if not traveler_pricings:
            return BaggageInfo()
        fare_detail = traveler_pricings[0].get("fareDetailsBySegment", [{}])[0]
        included = fare_detail.get("includedCheckedBags", {})
        quantity = included.get("quantity", 0)
        weight = included.get("weight")
        return BaggageInfo(
            checked_bags_included=quantity,
            carry_on_included=True,
            checked_bag_weight_kg=weight,
        )

    @staticmethod
    def _parse_fare_conditions(traveler_pricings: list[dict]) -> FareConditions:
        if not traveler_pricings:
            return FareConditions()
        fare_detail = traveler_pricings[0].get("fareDetailsBySegment", [{}])[0]
        fare_class = fare_detail.get("class")
        return FareConditions(
            is_refundable=False,   # Amadeus free-search doesn't return refundability; use fare class heuristics
            fare_class=fare_class,
        )

    @staticmethod
    def _basic_price_intel(total_usd: float, req: SearchRequest) -> PriceIntelligence:
        """
        Phase 1 placeholder: No real historical data yet.
        Phase 2 will replace this with the XGBoost classifier output.
        """
        return PriceIntelligence(
            price_label=PriceLabel.UNKNOWN,
            action_reason="Price intelligence training data is being collected for this route.",
            badge_text="",
            confidence=0.0,
        )
