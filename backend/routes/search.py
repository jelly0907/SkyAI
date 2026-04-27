"""
SkyAI — Search Routes

Endpoints:
  POST /search/intent   — parse natural language → SearchRequest
  POST /search/flights  — execute flight search → SearchResponse
"""

from __future__ import annotations

import logging
import re
import uuid
from datetime import date, datetime, timezone, timedelta
from typing import Optional

from fastapi import APIRouter, HTTPException, Request, status

from db.database import AsyncSessionLocal
from db.models_sql import PriceObservation
from db.repositories import ObservationRepo
from models import (
    CabinClass, FlightOffer, IntentRequest, IntentResponse, SearchRequest,
    SearchResponse, TripType,
)
from price_intel.provider import get_price_intel_engine

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/search", tags=["search"])


# ── Intent Parser ─────────────────────────────────────────────────────────────

# Simple IATA code dictionary for common cities (extended in production with full DB)
CITY_TO_IATA: dict[str, str] = {
    # North America
    "san francisco": "SFO", "sf": "SFO", "sfo": "SFO",
    "new york": "JFK", "nyc": "JFK", "new york city": "JFK",
    "los angeles": "LAX", "la": "LAX", "lax": "LAX",
    "chicago": "ORD", "london": "LHR",
    "paris": "CDG", "tokyo": "NRT", "osaka": "KIX",
    "seoul": "ICN", "beijing": "PEK", "shanghai": "PVG",
    "hong kong": "HKG", "singapore": "SIN", "bangkok": "BKK",
    "bali": "DPS", "dubai": "DXB", "amsterdam": "AMS",
    "frankfurt": "FRA", "rome": "FCO", "barcelona": "BCN",
    "madrid": "MAD", "sydney": "SYD", "melbourne": "MEL",
    "toronto": "YYZ", "vancouver": "YVR", "montreal": "YUL",
    "miami": "MIA", "las vegas": "LAS", "seattle": "SEA",
    "boston": "BOS", "washington": "IAD", "dc": "IAD",
    "cancun": "CUN", "mexico city": "MEX",
    "sao paulo": "GRU", "buenos aires": "EZE",
    "cairo": "CAI", "johannesburg": "JNB", "nairobi": "NBO",
    "mumbai": "BOM", "delhi": "DEL", "bangalore": "BLR",
    "taipei": "TPE", "kuala lumpur": "KUL", "manila": "MNL",
}

MONTH_MAP: dict[str, int] = {
    "january": 1, "jan": 1, "february": 2, "feb": 2,
    "march": 3, "mar": 3, "april": 4, "apr": 4,
    "may": 5, "june": 6, "jun": 6, "july": 7, "jul": 7,
    "august": 8, "aug": 8, "september": 9, "sep": 9, "sept": 9,
    "october": 10, "oct": 10, "november": 11, "nov": 11,
    "december": 12, "dec": 12,
}


def _resolve_city(text: str) -> Optional[str]:
    text = text.strip().lower()
    # Direct IATA match
    if len(text) == 3 and text.upper() in {v for v in CITY_TO_IATA.values()}:
        return text.upper()
    # City name match
    for city, iata in CITY_TO_IATA.items():
        if city in text:
            return iata
    return None


def _resolve_date(text: str) -> Optional[date]:
    text = text.lower()

    # Relative dates
    today = date.today()
    if "today" in text:
        return today
    if "tomorrow" in text:
        return today + timedelta(days=1)
    if "next week" in text:
        return today + timedelta(weeks=1)

    # "in X days/weeks"
    m = re.search(r"in (\d+) (day|week)", text)
    if m:
        n = int(m.group(1))
        return today + timedelta(days=n if "day" in m.group(2) else n * 7)

    # Weekday names — "next monday", "this friday", or bare "saturday".
    # "this <weekday>" → the upcoming instance (today if it's that day).
    # "next <weekday>" → the instance after that.
    # bare weekday    → same as "this".
    weekdays = {
        "monday": 0, "tuesday": 1, "wednesday": 2, "thursday": 3,
        "friday": 4, "saturday": 5, "sunday": 6,
    }
    m = re.search(r"(?:(next|this)\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)", text)
    if m:
        modifier = m.group(1)  # "next", "this", or None
        target = weekdays[m.group(2)]
        days_ahead = (target - today.weekday()) % 7
        if modifier == "next":
            # Always next week's instance (skip past current week).
            days_ahead = days_ahead or 7
            if days_ahead < 7:
                days_ahead += 7
        else:
            # "this" or bare — next occurrence; if today is the day, use today.
            # No-op: days_ahead is already correct (0 if today).
            pass
        return today + timedelta(days=days_ahead)

    # "Month Day" or "Month Day, Year"
    for month_name, month_num in MONTH_MAP.items():
        pattern = rf"{month_name}\s+(\d{{1,2}})(?:st|nd|rd|th)?(?:,?\s*(\d{{4}}))?"
        m = re.search(pattern, text)
        if m:
            day = int(m.group(1))
            year = int(m.group(2)) if m.group(2) else today.year
            try:
                d = date(year, month_num, day)
                if d < today:
                    d = date(year + 1, month_num, day)
                return d
            except ValueError:
                continue

    # ISO date (YYYY-MM-DD)
    m = re.search(r"(\d{4}-\d{2}-\d{2})", text)
    if m:
        try:
            return date.fromisoformat(m.group(1))
        except ValueError:
            pass

    # Month only → first of that month
    for month_name, month_num in MONTH_MAP.items():
        if month_name in text:
            year = today.year
            d = date(year, month_num, 1)
            if d < today:
                d = date(year + 1, month_num, 1)
            return d

    return None


def _parse_natural_language(query: str) -> tuple[SearchRequest, float, str]:
    """
    Rule-based NL parser. Returns (SearchRequest, confidence, interpretation).
    Handles common patterns like:
      "flights from SFO to Tokyo in July"
      "cheapest roundtrip to London next week for 2 adults"
      "one way to Bangkok on July 15"
    """
    text = query.lower()
    confidence = 1.0
    notes = []

    # Words that terminate origin/destination captures. Includes prepositions
    # (in/on/for/from/to), date keywords (next/this/today/tomorrow), and
    # weekday names — otherwise a query like "JFK to LHR next Friday" would
    # greedily capture "LHR next Friday" as the destination and fail.
    _LOC_END = (
        r"(?:\s+to|\s+in|\s+on|\s+for|\s+from|"
        r"\s+next|\s+this|\s+today|\s+tomorrow|"
        r"\s+(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)|"
        r"\s+jan(?:uary)?|\s+feb(?:ruary)?|\s+mar(?:ch)?|\s+apr(?:il)?|"
        r"\s+may|\s+jun(?:e)?|\s+jul(?:y)?|\s+aug(?:ust)?|"
        r"\s+sep(?:t|tember)?|\s+oct(?:ober)?|\s+nov(?:ember)?|\s+dec(?:ember)?|"
        r"$)"
    )

    # ── Origin ───────────────────────────────────────────────────────────────
    # Two patterns: "from X to Y" (preferred) and bare "X to Y" (e.g. "JFK
    # to LHR next Friday"). Try the explicit "from" form first; fall back
    # to the bare form so users don't have to type "from".
    origin = None
    from_match = re.search(r"from\s+([a-z\s]{2,20}?)" + _LOC_END, text)
    if from_match:
        origin = _resolve_city(from_match.group(1))
    if not origin:
        bare_match = re.match(r"\s*([a-z\s]{2,20}?)\s+to\s+", text)
        if bare_match:
            origin = _resolve_city(bare_match.group(1))
    if not origin:
        confidence -= 0.3
        origin = "SFO"   # default to user's home airport (from profile in production)
        notes.append("Could not detect origin — defaulting to SFO")

    # ── Destination ───────────────────────────────────────────────────────────
    destination = None
    to_match = re.search(r"to\s+([a-z\s]{2,20}?)" + _LOC_END, text)
    if to_match:
        destination = _resolve_city(to_match.group(1))
    if not destination:
        confidence -= 0.4
        notes.append("Could not detect destination")

    # ── Trip type ─────────────────────────────────────────────────────────────
    if any(w in text for w in ["one way", "one-way", "oneway"]):
        trip_type = TripType.ONE_WAY
    else:
        trip_type = TripType.ROUNDTRIP

    # ── Dates ─────────────────────────────────────────────────────────────────
    today = date.today()
    departure_date = _resolve_date(text)
    if not departure_date:
        departure_date = today + timedelta(days=30)
        confidence -= 0.1
        notes.append("No departure date found — defaulting to 30 days from now")

    return_date = None
    if trip_type == TripType.ROUNDTRIP:
        # Look for return after departure
        ret_match = re.search(r"return(?:ing)?\s+(?:on\s+)?([a-z0-9\s,]+)", text)
        if ret_match:
            return_date = _resolve_date(ret_match.group(1))
        if not return_date:
            return_date = departure_date + timedelta(days=7)
            notes.append("No return date found — defaulting to 7 days after departure")

    # ── Passengers ────────────────────────────────────────────────────────────
    adults = 1
    adult_match = re.search(r"(\d+)\s+(?:adult|passenger|person|people|travell?er)", text)
    if adult_match:
        adults = min(int(adult_match.group(1)), 9)

    children = 0
    child_match = re.search(r"(\d+)\s+(?:child|kid|children|kids)", text)
    if child_match:
        children = min(int(child_match.group(1)), 9)

    # ── Cabin ─────────────────────────────────────────────────────────────────
    cabin = CabinClass.ECONOMY
    if any(w in text for w in ["business class", "business", "biz class"]):
        cabin = CabinClass.BUSINESS
    elif any(w in text for w in ["first class", "first"]):
        cabin = CabinClass.FIRST
    elif any(w in text for w in ["premium economy", "premium"]):
        cabin = CabinClass.PREMIUM_ECONOMY

    # ── Non-stop ──────────────────────────────────────────────────────────────
    non_stop = any(w in text for w in ["direct", "non-stop", "nonstop", "no stops", "no layover"])

    # ── Build interpretation string ───────────────────────────────────────────
    interpretation = (
        f"{trip_type.value.replace('_', ' ').title()} flight: "
        f"{origin or '?'} → {destination or '?'}, "
        f"departing {departure_date.strftime('%b %d, %Y')}"
    )
    if return_date:
        interpretation += f", returning {return_date.strftime('%b %d, %Y')}"
    interpretation += f". {adults} adult(s)"
    if children:
        interpretation += f", {children} child(ren)"
    interpretation += f". {cabin.value.replace('_', ' ').title()} class."
    if non_stop:
        interpretation += " Direct flights only."
    if notes:
        interpretation += f" Note: {'; '.join(notes)}."

    if not destination:
        raise ValueError("Could not determine destination from query. Please specify a destination city.")

    search_req = SearchRequest(
        origin=origin,
        destination=destination,
        departure_date=departure_date,
        return_date=return_date if trip_type == TripType.ROUNDTRIP else None,
        adults=adults,
        children=children,
        cabin_class=cabin,
        trip_type=trip_type,
        non_stop_only=non_stop,
    )

    return search_req, max(0.0, min(1.0, confidence)), interpretation


# ── Route Handlers ────────────────────────────────────────────────────────────

@router.post("/intent", response_model=IntentResponse, summary="Parse natural language query")
async def parse_intent(body: IntentRequest) -> IntentResponse:
    """
    Accepts a free-text query and returns a structured SearchRequest.
    Used by the mobile NL search input to populate the search form fields.
    """
    try:
        search_req, confidence, interpretation = _parse_natural_language(body.query)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))

    return IntentResponse(
        search_request=search_req,
        confidence=confidence,
        raw_query=body.query,
        interpretation=interpretation,
    )


async def _log_observations(
    offers: list[FlightOffer], req: SearchRequest, provider: str
) -> None:
    """Persist a PriceObservation per offer. Never raises — logging must never
    break the search response."""
    try:
        from datetime import datetime, time, timezone as _tz
        dep_dt = datetime.combine(req.departure_date, time.min, tzinfo=_tz.utc)
        ret_dt = (
            datetime.combine(req.return_date, time.min, tzinfo=_tz.utc)
            if req.return_date else None
        )

        rows: list[PriceObservation] = []
        for o in offers:
            if not o.itineraries:
                continue
            first_seg = o.itineraries[0].segments[0]
            rows.append(PriceObservation(
                origin=req.origin.upper(),
                destination=req.destination.upper(),
                departure_date=dep_dt,
                return_date=ret_dt,
                airline=first_seg.carrier_code,
                flight_number=first_seg.flight_number,
                cabin_class=req.cabin_class.value,
                price_usd=o.price.total_usd,
                stops=o.total_stops,
                total_duration_minutes=sum(i.total_duration_minutes for i in o.itineraries),
                source=o.source or provider,
                price_label=(o.price_intelligence.price_label.value
                             if o.price_intelligence else None),
                seats_remaining=o.seats_remaining,
            ))
        if not rows:
            return
        async with AsyncSessionLocal() as session:
            await ObservationRepo(session).bulk_log(rows)
    except Exception as e:       # noqa: BLE001
        logger.warning("Failed to log price observations: %s", e)


@router.post("/flights", response_model=SearchResponse, summary="Search for flights")
async def search_flights(body: SearchRequest, request: Request) -> SearchResponse:
    """
    Executes a flight search against the configured provider (mock / Duffel / Amadeus).
    Returns offers enriched with Price Intelligence and logs each price point
    to the price history database for future ML training.
    """
    provider = getattr(request.app.state, "provider", "mock")

    try:
        if provider == "mock":
            from mock_data import generate_mock_offers
            offers = generate_mock_offers(body)
        else:
            client = request.app.state.flight_client
            offers = await client.search_flights(body)
    except Exception as e:
        logger.exception(f"Flight search failed ({provider}): {e}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Flight search failed: {str(e)}",
        )

    # Run offers through the Price Intelligence engine (idempotent — overrides
    # any pre-existing intelligence with the current engine's classification).
    engine = get_price_intel_engine()
    offers = engine.enrich_offers(offers, body.departure_date)

    # Log every offer as a price observation (fire-and-forget; never fails the
    # response).
    await _log_observations(offers, body, provider)

    return SearchResponse(
        query_id=str(uuid.uuid4()),
        search_request=body,
        offers=offers,
        total_found=len(offers),
        sources_queried=[provider],
        returned_at=datetime.now(timezone.utc),
    )
