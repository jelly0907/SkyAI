"""
SkyAI — Shared Pydantic Models
Defines the canonical data shapes used across the API.
"""

from __future__ import annotations
from datetime import date, datetime
from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field


# ── Enums ────────────────────────────────────────────────────────────────────

class CabinClass(str, Enum):
    ECONOMY = "ECONOMY"
    PREMIUM_ECONOMY = "PREMIUM_ECONOMY"
    BUSINESS = "BUSINESS"
    FIRST = "FIRST"

class TripType(str, Enum):
    ROUNDTRIP = "roundtrip"
    ONE_WAY = "one_way"
    MULTI_CITY = "multi_city"

class PriceLabel(str, Enum):
    STEAL = "STEAL"
    GREAT_DEAL = "GREAT_DEAL"
    FAIR = "FAIR"
    EXPENSIVE = "EXPENSIVE"
    OVERPRICED = "OVERPRICED"
    UNKNOWN = "UNKNOWN"         # Not enough history for this route yet

class PriceTrend(str, Enum):
    RISING = "RISING"
    FALLING = "FALLING"
    STABLE = "STABLE"
    VOLATILE = "VOLATILE"

class ActionType(str, Enum):
    BUY_NOW = "BUY_NOW"
    WAIT = "WAIT"
    SET_ALERT = "SET_ALERT"
    MONITOR = "MONITOR"


# ── Search Request / Intent ───────────────────────────────────────────────────

class SearchRequest(BaseModel):
    """
    Structured search parameters sent from the mobile app.
    Can be built from natural language parsing or directly from the search form.
    """
    origin: str = Field(..., min_length=3, max_length=3, description="IATA airport code (e.g. SFO)")
    destination: str = Field(..., min_length=3, max_length=3, description="IATA airport code (e.g. NRT)")
    departure_date: date = Field(..., description="Departure date")
    return_date: Optional[date] = Field(None, description="Return date for roundtrip")
    adults: int = Field(1, ge=1, le=9)
    children: int = Field(0, ge=0, le=9)
    infants: int = Field(0, ge=0, le=9)
    cabin_class: CabinClass = Field(CabinClass.ECONOMY)
    trip_type: TripType = Field(TripType.ROUNDTRIP)
    max_results: int = Field(20, ge=1, le=50)
    non_stop_only: bool = Field(False)

    class Config:
        json_schema_extra = {
            "example": {
                "origin": "SFO",
                "destination": "NRT",
                "departure_date": "2026-07-15",
                "return_date": "2026-07-25",
                "adults": 2,
                "cabin_class": "ECONOMY",
                "trip_type": "roundtrip"
            }
        }


class IntentRequest(BaseModel):
    """Natural language query sent to the intent parser."""
    query: str = Field(..., min_length=3, max_length=500)


class IntentResponse(BaseModel):
    """Parsed search intent returned to the mobile app."""
    search_request: SearchRequest
    confidence: float = Field(..., ge=0.0, le=1.0)
    raw_query: str
    interpretation: str     # Human-readable explanation of what was parsed


# ── Flight Data Models ────────────────────────────────────────────────────────

class Segment(BaseModel):
    """One leg of a flight (one takeoff → one landing)."""
    origin: str
    destination: str
    departure_at: datetime
    arrival_at: datetime
    carrier_code: str
    flight_number: str
    aircraft_code: Optional[str] = None
    duration_minutes: int
    cabin: CabinClass


class Itinerary(BaseModel):
    """One direction of travel (outbound or return), may have multiple segments."""
    segments: list[Segment]
    total_duration_minutes: int
    stops: int


class PriceBreakdown(BaseModel):
    total_usd: float
    base_fare_usd: float
    taxes_usd: float
    fees_usd: float = 0.0
    per_adult_usd: Optional[float] = None


class BaggageInfo(BaseModel):
    checked_bags_included: int = 0
    carry_on_included: bool = True
    checked_bag_weight_kg: Optional[int] = None


class FareConditions(BaseModel):
    is_refundable: bool = False
    change_fee_usd: Optional[float] = None
    fare_class: Optional[str] = None


class PriceIntelligence(BaseModel):
    """
    ML-enriched price analysis. In Phase 1 this uses simple percentile rules.
    Full ML models (XGBoost + Prophet) will be wired in Phase 2.
    """
    price_label: PriceLabel = PriceLabel.UNKNOWN
    price_percentile: Optional[int] = None     # 0–100; lower = cheaper
    savings_vs_median_usd: Optional[float] = None
    savings_pct: Optional[float] = None
    trend: PriceTrend = PriceTrend.STABLE
    forecast_7d_usd: Optional[float] = None
    forecast_14d_usd: Optional[float] = None
    action: ActionType = ActionType.MONITOR
    action_reason: str = "Monitoring price — not enough history yet."
    badge_text: str = ""
    confidence: float = 0.0


class FlightOffer(BaseModel):
    """
    A single flight offer: one itinerary (or two for roundtrip),
    enriched with price intelligence.
    """
    offer_id: str
    source: str                              # "amadeus" | "skyscanner" | "airline_direct"
    itineraries: list[Itinerary]             # [outbound] or [outbound, return]
    price: PriceBreakdown
    baggage: BaggageInfo
    fare_conditions: FareConditions
    seats_remaining: Optional[int] = None
    price_intelligence: PriceIntelligence = PriceIntelligence()
    booking_url: Optional[str] = None
    last_ticketing_date: Optional[date] = None

    @property
    def primary_carrier(self) -> str:
        return self.itineraries[0].segments[0].carrier_code

    @property
    def total_stops(self) -> int:
        return sum(i.stops for i in self.itineraries)


# ── API Response Models ───────────────────────────────────────────────────────

class SearchResponse(BaseModel):
    """Top-level search response returned to mobile apps."""
    query_id: str
    search_request: SearchRequest
    offers: list[FlightOffer]
    total_found: int
    sources_queried: list[str]
    returned_at: datetime
    currency: str = "USD"
    meta: dict = {}


class ErrorResponse(BaseModel):
    error: str
    detail: Optional[str] = None
    code: Optional[str] = None


# ── Price Watch Alert Models ──────────────────────────────────────────────────

class WatchCreateRequest(BaseModel):
    """Request body for POST /watch."""
    user_id: str = Field(..., min_length=1, max_length=64,
                         description="Client-supplied user ID (auth comes in Phase 3).")
    origin: str = Field(..., min_length=3, max_length=3)
    destination: str = Field(..., min_length=3, max_length=3)
    departure_date: date
    return_date: Optional[date] = None
    cabin_class: CabinClass = CabinClass.ECONOMY
    adults: int = Field(1, ge=1, le=9)
    max_stops: Optional[int] = Field(None, ge=0, le=3)
    target_price_usd: Optional[float] = Field(
        None, ge=0,
        description="Alert fires when observed price drops to or below this.",
    )
    notify_on_great_deal: bool = Field(
        True,
        description="Also alert when our engine classifies the price STEAL or GREAT_DEAL, "
                    "even if no target_price_usd was set.",
    )

    class Config:
        json_schema_extra = {
            "example": {
                "user_id": "demo-user",
                "origin": "SFO",
                "destination": "NRT",
                "departure_date": "2026-07-15",
                "return_date": "2026-07-25",
                "cabin_class": "ECONOMY",
                "adults": 1,
                "target_price_usd": 800,
                "notify_on_great_deal": True,
            }
        }


class WatchResponse(BaseModel):
    """Shape returned by the /watch endpoints."""
    id: str
    user_id: str
    origin: str
    destination: str
    departure_date: date
    return_date: Optional[date] = None
    cabin_class: CabinClass
    adults: int
    max_stops: Optional[int] = None
    target_price_usd: Optional[float] = None
    notify_on_great_deal: bool
    active: bool
    created_at: datetime
    last_checked_at: Optional[datetime] = None
    last_price_usd: Optional[float] = None
    last_label: Optional[PriceLabel] = None
    triggered_at: Optional[datetime] = None
    trigger_count: int = 0


class WatchCheckResponse(BaseModel):
    """Result of POST /watch/{id}/check — did the watch fire?"""
    watch: WatchResponse
    triggered: bool
    best_price_usd: Optional[float] = None
    best_label: Optional[PriceLabel] = None
    best_offer: Optional[FlightOffer] = None
    reason: str
    checked_at: datetime
