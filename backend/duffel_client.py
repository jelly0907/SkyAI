"""
SkyAI — Duffel API Client

Duffel (duffel.com) is a modern flight booking API.
Sign up at: https://app.duffel.com/signup
Get your API key from: Dashboard → Access tokens → Create token

API docs: https://duffel.com/docs/api

Flow:
  1. POST /air/offer_requests  → creates a search, returns offer_request_id
  2. GET  /air/offers?offer_request_id={id}  → returns paginated list of offers
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Optional

import httpx

from models import (
    BaggageInfo, CabinClass, FareConditions, FlightOffer, Itinerary,
    PriceBreakdown, PriceIntelligence, PriceLabel, SearchRequest, Segment,
    TripType,
)

logger = logging.getLogger(__name__)

DUFFEL_BASE = "https://api.duffel.com"
DUFFEL_VERSION = "v2"          # Current stable API version (v1 was retired)
API_VERSION_HEADER = "v2"      # Duffel-Version header value

CABIN_MAP_TO_DUFFEL = {
    CabinClass.ECONOMY: "economy",
    CabinClass.PREMIUM_ECONOMY: "premium_economy",
    CabinClass.BUSINESS: "business",
    CabinClass.FIRST: "first",
}

CABIN_MAP_FROM_DUFFEL = {v: k for k, v in CABIN_MAP_TO_DUFFEL.items()}


class DuffelClient:
    """
    Async Duffel API client.
    Instantiate once, call start() on app startup, stop() on shutdown.
    """

    def __init__(self, api_key: str):
        self._api_key = api_key
        self._http: Optional[httpx.AsyncClient] = None

    async def start(self) -> None:
        self._http = httpx.AsyncClient(
            base_url=DUFFEL_BASE,
            headers={
                "Authorization": f"Bearer {self._api_key}",
                "Duffel-Version": API_VERSION_HEADER,
                "Accept": "application/json",
                "Content-Type": "application/json",
            },
            timeout=httpx.Timeout(30.0),
            http2=True,
        )

    async def stop(self) -> None:
        if self._http:
            await self._http.aclose()

    # ── Public ────────────────────────────────────────────────────────────────

    async def search_flights(self, req: SearchRequest) -> list[FlightOffer]:
        """
        Execute a flight search via Duffel.
        Step 1: Create offer request → get offer_request_id
        Step 2: Fetch all offers for that request
        """
        assert self._http is not None, "Call start() before searching."

        logger.info("Duffel: search_flights() called for %s→%s %s",
                    req.origin, req.destination, req.departure_date)
        offer_request_id = await self._create_offer_request(req)
        logger.info("Duffel: offer_request created, fetching offers")
        raw_offers = await self._fetch_offers(offer_request_id)
        logger.info("Duffel: %d raw offers received, normalizing", len(raw_offers))

        # Normalize offer-by-offer so a single malformed payload doesn't
        # take down the entire search response. Log and skip on failure.
        offers: list[FlightOffer] = []
        skipped = 0
        for raw in raw_offers:
            try:
                offers.append(self._normalize_offer(raw))
            except Exception as e:        # noqa: BLE001
                skipped += 1
                logger.warning(
                    "Duffel: failed to normalize offer id=%s: %s",
                    raw.get("id", "?"), e,
                )
        if skipped:
            logger.warning(f"Duffel: skipped {skipped} unparseable offers (kept {len(offers)})")
        offers.sort(key=lambda o: o.price.total_usd)
        return offers

    # ── Step 1: Create Offer Request ──────────────────────────────────────────

    async def _create_offer_request(self, req: SearchRequest) -> str:
        """
        POST /air/offer_requests
        Tells Duffel what we're searching for.
        Returns the offer_request_id to use in step 2.
        """
        # Build slices (outbound + optional return)
        slices = [
            {
                "origin": req.origin.upper(),
                "destination": req.destination.upper(),
                "departure_date": req.departure_date.isoformat(),
            }
        ]
        if req.trip_type == TripType.ROUNDTRIP and req.return_date:
            slices.append({
                "origin": req.destination.upper(),
                "destination": req.origin.upper(),
                "departure_date": req.return_date.isoformat(),
            })

        # Build passengers list
        passengers = [{"type": "adult"} for _ in range(req.adults)]
        passengers += [{"type": "child"} for _ in range(req.children)]
        passengers += [{"type": "infant_without_seat"} for _ in range(req.infants)]

        cabin_class = CABIN_MAP_TO_DUFFEL.get(req.cabin_class, "economy")

        payload = {
            "data": {
                "slices": slices,
                "passengers": passengers,
                "cabin_class": cabin_class,
                "max_connections": 0 if req.non_stop_only else 1,
            }
        }

        logger.info(f"Duffel: creating offer request {req.origin}→{req.destination}")
        resp = await self._http.post("/air/offer_requests", json=payload)

        if resp.status_code != 201:
            body = resp.text
            logger.error(f"Duffel offer request failed {resp.status_code}: {body}")
            raise RuntimeError(f"Duffel API error {resp.status_code}: {body}")

        data = resp.json()["data"]
        offer_request_id = data["id"]
        logger.info(f"Duffel: offer_request_id = {offer_request_id}")
        return offer_request_id

    # ── Step 2: Fetch Offers ──────────────────────────────────────────────────

    async def _fetch_offers(self, offer_request_id: str) -> list[dict]:
        """
        GET /air/offers?offer_request_id={id}
        Paginates through all offers and returns the raw list.
        """
        all_offers: list[dict] = []
        after: Optional[str] = None

        while True:
            params: dict = {
                "offer_request_id": offer_request_id,
                "limit": 50,
                "sort": "total_amount",
            }
            if after:
                params["after"] = after

            resp = await self._http.get("/air/offers", params=params)
            resp.raise_for_status()
            body = resp.json()

            all_offers.extend(body.get("data", []))

            # Pagination
            meta = body.get("meta", {})
            after = meta.get("after")
            if not after or len(all_offers) >= 50:
                break

        logger.info(f"Duffel: fetched {len(all_offers)} offers")
        return all_offers

    # ── Normalize ─────────────────────────────────────────────────────────────

    def _normalize_offer(self, raw: dict) -> FlightOffer:
        """Convert Duffel offer dict → SkyAI FlightOffer schema."""

        # Itineraries (Duffel calls them "slices")
        itineraries = [self._parse_slice(s) for s in (raw.get("slices") or [])]

        # Price — Duffel returns total_amount + total_currency
        total = float(raw.get("total_amount", 0))
        base = float(raw.get("base_amount", total * 0.82))
        taxes = round(total - base, 2)

        # Per-passenger price — divide total by number of adults.
        passengers = raw.get("passengers") or []
        per_adult = None
        if passengers:
            adult_count = sum(1 for p in passengers if p.get("type") == "adult")
            if adult_count:
                per_adult = round(total / adult_count, 2)

        price = PriceBreakdown(
            total_usd=total,
            base_fare_usd=base,
            taxes_usd=taxes,
            per_adult_usd=per_adult,
        )

        # Baggage from conditions_at_ticketing
        baggage = self._parse_baggage(raw)

        # Fare conditions
        fare_conditions = self._parse_fare_conditions(raw)

        # Availability
        available_services = raw.get("available_services", [])
        # Duffel doesn't always expose seats remaining directly

        return FlightOffer(
            offer_id=raw.get("id", str(uuid.uuid4())),
            source="duffel",
            itineraries=itineraries,
            price=price,
            baggage=baggage,
            fare_conditions=fare_conditions,
            seats_remaining=None,
            price_intelligence=PriceIntelligence(
                price_label=PriceLabel.UNKNOWN,
                action_reason="Price intelligence is being collected for this route.",
                confidence=0.0,
            ),
            booking_url=None,
        )

    def _parse_slice(self, raw_slice: dict) -> Itinerary:
        """Convert a Duffel slice (one direction) → SkyAI Itinerary."""
        segments: list[Segment] = []

        for seg in raw_slice.get("segments") or []:
            # Every nested object below can be null in Duffel v2 — coerce
            # with `or {}` rather than relying on .get(key, {}), which only
            # defaults missing keys, not explicit nulls.
            origin = (seg.get("origin") or {}).get("iata_code", "")
            destination = (seg.get("destination") or {}).get("iata_code", "")

            dep_str = seg.get("departing_at") or ""
            arr_str = seg.get("arriving_at") or ""

            dep_dt = datetime.fromisoformat(dep_str) if dep_str else datetime.now(timezone.utc)
            arr_dt = datetime.fromisoformat(arr_str) if arr_str else datetime.now(timezone.utc)
            duration_min = int((arr_dt - dep_dt).total_seconds() / 60)

            carrier = (seg.get("marketing_carrier") or {}).get("iata_code", "")
            flight_num = str(seg.get("marketing_carrier_flight_number") or "")
            aircraft_raw = seg.get("aircraft") or {}
            aircraft = aircraft_raw.get("name") if aircraft_raw else None

            # Cabin — Duffel puts it at the passenger level; use slice-level cabin as fallback
            cabin_raw = (raw_slice.get("fare_brand_name") or "").lower()
            cabin = CabinClass.ECONOMY  # default
            for duffel_cabin, skyai_cabin in CABIN_MAP_FROM_DUFFEL.items():
                if duffel_cabin in cabin_raw:
                    cabin = skyai_cabin
                    break

            segments.append(Segment(
                origin=origin,
                destination=destination,
                departure_at=dep_dt,
                arrival_at=arr_dt,
                carrier_code=carrier,
                flight_number=flight_num,
                aircraft_code=aircraft,
                duration_minutes=duration_min,
                cabin=cabin,
            ))

        total_duration_str = raw_slice.get("duration", "PT0M")
        total_duration = self._parse_iso_duration(total_duration_str)
        stops = len(segments) - 1

        return Itinerary(
            segments=segments,
            total_duration_minutes=total_duration,
            stops=stops,
        )

    @staticmethod
    def _parse_iso_duration(duration_str: str) -> int:
        """Parse ISO 8601 duration (e.g. 'PT9H55M') → minutes."""
        import re
        h = int((re.search(r"(\d+)H", duration_str) or type("x",(),{"group":lambda s,n:0})()).group(1) or 0)
        m = int((re.search(r"(\d+)M", duration_str) or type("x",(),{"group":lambda s,n:0})()).group(1) or 0)
        return h * 60 + m

    @staticmethod
    def _parse_baggage(raw: dict) -> BaggageInfo:
        """
        Duffel surfaces baggage in conditions_at_ticketing.baggages per passenger.
        We use the first adult passenger's allowance.
        """
        for passenger in raw.get("passengers") or []:
            if passenger.get("type") == "adult":
                baggages = passenger.get("baggages") or []
                checked = sum(
                    b.get("quantity", 0)
                    for b in baggages if b.get("type") == "checked"
                )
                return BaggageInfo(
                    checked_bags_included=checked,
                    carry_on_included=True,
                )
        return BaggageInfo()

    @staticmethod
    def _parse_fare_conditions(raw: dict) -> FareConditions:
        """
        Duffel exposes conditions in conditions_at_ticketing (refund/change).
        """
        # Duffel returns these keys with null values when conditions are
        # unknown/unavailable, so .get(key, {}) isn't enough — we need the
        # `or {}` to coerce explicit nulls to an empty dict.
        conditions = raw.get("conditions") or {}
        refund = conditions.get("refund_before_departure") or {}
        change = conditions.get("change_before_departure") or {}

        is_refundable = refund.get("allowed", False)
        change_allowed = change.get("allowed", False)
        change_penalty = change.get("penalty_amount")
        change_fee = float(change_penalty) if change_penalty and change_allowed else None

        return FareConditions(
            is_refundable=is_refundable,
            change_fee_usd=change_fee,
        )
