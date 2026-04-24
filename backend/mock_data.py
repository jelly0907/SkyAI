"""
SkyAI — Mock Flight Data Provider

Returns realistic flight data when USE_MOCK_DATA=true in .env.
All prices, durations, airlines, and price intelligence are based on
real-world typical values for each route type.

To switch to a real API: set USE_MOCK_DATA=false and add API credentials.
"""

from __future__ import annotations

import hashlib
import random
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from models import (
    ActionType, BaggageInfo, CabinClass, FareConditions, FlightOffer,
    Itinerary, PriceBreakdown, PriceIntelligence, PriceLabel, PriceTrend,
    SearchRequest, Segment, TripType,
)

# ── Airline Catalog ───────────────────────────────────────────────────────────

AIRLINES: dict[str, dict] = {
    "NH": {"name": "ANA",              "rating": 4.8, "on_time": 0.91},
    "JL": {"name": "Japan Airlines",   "rating": 4.7, "on_time": 0.89},
    "UA": {"name": "United Airlines",  "rating": 3.8, "on_time": 0.79},
    "AA": {"name": "American Airlines","rating": 3.7, "on_time": 0.78},
    "DL": {"name": "Delta Air Lines",  "rating": 4.0, "on_time": 0.82},
    "SQ": {"name": "Singapore Airlines","rating": 4.9, "on_time": 0.90},
    "CX": {"name": "Cathay Pacific",   "rating": 4.6, "on_time": 0.87},
    "EK": {"name": "Emirates",         "rating": 4.7, "on_time": 0.85},
    "LH": {"name": "Lufthansa",        "rating": 4.3, "on_time": 0.83},
    "BA": {"name": "British Airways",  "rating": 4.1, "on_time": 0.80},
    "AF": {"name": "Air France",       "rating": 4.2, "on_time": 0.81},
    "KE": {"name": "Korean Air",       "rating": 4.5, "on_time": 0.88},
    "OZ": {"name": "Asiana Airlines",  "rating": 4.4, "on_time": 0.86},
    "TK": {"name": "Turkish Airlines", "rating": 4.3, "on_time": 0.82},
    "QR": {"name": "Qatar Airways",    "rating": 4.8, "on_time": 0.88},
    "WN": {"name": "Southwest",        "rating": 3.9, "on_time": 0.80},
    "B6": {"name": "JetBlue",          "rating": 3.8, "on_time": 0.76},
    "AS": {"name": "Alaska Airlines",  "rating": 4.1, "on_time": 0.84},
}

AIRCRAFT: list[str] = [
    "Boeing 787-9", "Boeing 777-300ER", "Boeing 737-900",
    "Airbus A350-900", "Airbus A380-800", "Airbus A321neo",
    "Boeing 787-10", "Airbus A330-300",
]

# ── Route Database ────────────────────────────────────────────────────────────
# Defines realistic price ranges, duration, and which airlines serve each route.
# Routes are matched by origin+destination regardless of direction.

ROUTE_DB: dict[frozenset, dict] = {
    frozenset({"SFO", "NRT"}): {
        "duration_min": 595, "duration_max": 660,
        "price_min": 650, "price_median": 1050, "price_max": 1800,
        "airlines_direct": ["NH", "UA", "JL"],
        "airlines_1stop": ["DL", "AA", "KE"],
        "layover_hubs_direct": [],
        "layover_hubs_1stop": ["ICN", "LAX", "ORD"],
    },
    frozenset({"SFO", "LHR"}): {
        "duration_min": 580, "duration_max": 640,
        "price_min": 500, "price_median": 850, "price_max": 1600,
        "airlines_direct": ["BA", "UA", "AA"],
        "airlines_1stop": ["LH", "AF", "DL"],
        "layover_hubs_1stop": ["FRA", "CDG", "ORD"],
    },
    frozenset({"SFO", "CDG"}): {
        "duration_min": 660, "duration_max": 720,
        "price_min": 480, "price_median": 820, "price_max": 1500,
        "airlines_direct": ["AF", "UA"],
        "airlines_1stop": ["LH", "BA", "DL"],
        "layover_hubs_1stop": ["LHR", "FRA", "ORD"],
    },
    frozenset({"SFO", "SIN"}): {
        "duration_min": 880, "duration_max": 980,
        "price_min": 700, "price_median": 1100, "price_max": 2200,
        "airlines_direct": ["SQ"],
        "airlines_1stop": ["CX", "NH", "QR"],
        "layover_hubs_1stop": ["HKG", "NRT", "DXB"],
    },
    frozenset({"SFO", "BKK"}): {
        "duration_min": 950, "duration_max": 1100,
        "price_min": 580, "price_median": 950, "price_max": 1900,
        "airlines_direct": [],
        "airlines_1stop": ["NH", "CX", "SQ", "KE"],
        "layover_hubs_1stop": ["NRT", "HKG", "ICN"],
    },
    frozenset({"SFO", "DPS"}): {
        "duration_min": 1000, "duration_max": 1120,
        "price_min": 540, "price_median": 880, "price_max": 1700,
        "airlines_direct": [],
        "airlines_1stop": ["SQ", "CX", "NH"],
        "layover_hubs_1stop": ["SIN", "HKG", "NRT"],
    },
    frozenset({"SFO", "ICN"}): {
        "duration_min": 590, "duration_max": 660,
        "price_min": 580, "price_median": 950, "price_max": 1750,
        "airlines_direct": ["KE", "OZ", "UA"],
        "airlines_1stop": ["NH", "JL", "AA"],
        "layover_hubs_1stop": ["NRT", "LAX", "ORD"],
    },
    frozenset({"SFO", "DXB"}): {
        "duration_min": 870, "duration_max": 980,
        "price_min": 650, "price_median": 1150, "price_max": 2400,
        "airlines_direct": ["EK"],
        "airlines_1stop": ["QR", "TK", "LH"],
        "layover_hubs_1stop": ["DOH", "IST", "FRA"],
    },
    frozenset({"JFK", "LHR"}): {
        "duration_min": 415, "duration_max": 450,
        "price_min": 380, "price_median": 680, "price_max": 1400,
        "airlines_direct": ["BA", "AA", "UA", "DL"],
        "airlines_1stop": ["LH", "AF"],
        "layover_hubs_1stop": ["FRA", "CDG"],
    },
    frozenset({"LAX", "NRT"}): {
        "duration_min": 580, "duration_max": 640,
        "price_min": 580, "price_median": 980, "price_max": 1700,
        "airlines_direct": ["NH", "JL", "UA", "AA"],
        "airlines_1stop": ["KE", "DL"],
        "layover_hubs_1stop": ["ICN", "ORD"],
    },
}

# Default fallback for routes not in the database
DEFAULT_ROUTE = {
    "duration_min": 300, "duration_max": 480,
    "price_min": 200, "price_median": 500, "price_max": 1200,
    "airlines_direct": ["UA", "AA", "DL"],
    "airlines_1stop": ["B6", "AS", "WN"],
    "layover_hubs_1stop": ["ORD", "ATL", "DFW"],
}


# ── Price Intelligence Rules ──────────────────────────────────────────────────

def _compute_price_intelligence(price_usd: float, route: dict, days_out: int) -> PriceIntelligence:
    """
    Rule-based price intelligence for mock data.
    Mimics what the XGBoost model will do in Phase 2.
    """
    median = route["price_median"]
    p10 = route["price_min"] + (median - route["price_min"]) * 0.15
    p25 = route["price_min"] + (median - route["price_min"]) * 0.40
    p75 = median + (route["price_max"] - median) * 0.35
    p90 = median + (route["price_max"] - median) * 0.75

    # Percentile (approximate)
    if price_usd <= p10:
        percentile = int(price_usd / p10 * 10)
        label = PriceLabel.STEAL
        badge = "🔥 STEAL"
        confidence = 0.92
    elif price_usd <= p25:
        percentile = int(10 + (price_usd - p10) / (p25 - p10) * 15)
        label = PriceLabel.GREAT_DEAL
        badge = "✅ GREAT DEAL"
        confidence = 0.87
    elif price_usd <= p75:
        percentile = int(25 + (price_usd - p25) / (p75 - p25) * 50)
        label = PriceLabel.FAIR
        badge = ""
        confidence = 0.83
    elif price_usd <= p90:
        percentile = int(75 + (price_usd - p75) / (p90 - p75) * 15)
        label = PriceLabel.EXPENSIVE
        badge = "⚠️ ABOVE AVG"
        confidence = 0.80
    else:
        percentile = min(99, int(90 + (price_usd - p90) / (route["price_max"] - p90) * 10))
        label = PriceLabel.OVERPRICED
        badge = "🔴 OVERPRICED"
        confidence = 0.78

    savings_vs_median = round(median - price_usd, 2)
    savings_pct = round((savings_vs_median / median) * 100, 1) if savings_vs_median > 0 else None

    # Trend: simulate based on days out
    if days_out < 7:
        trend = PriceTrend.RISING
        forecast_7d = round(price_usd * 1.12, 2)
        forecast_14d = round(price_usd * 1.22, 2)
    elif days_out < 21:
        trend = PriceTrend.STABLE
        forecast_7d = round(price_usd * 1.03, 2)
        forecast_14d = round(price_usd * 1.08, 2)
    elif days_out < 45:
        trend = random.choice([PriceTrend.FALLING, PriceTrend.STABLE])
        forecast_7d = round(price_usd * 0.97, 2)
        forecast_14d = round(price_usd * 0.94, 2)
    else:
        trend = PriceTrend.FALLING
        forecast_7d = round(price_usd * 0.96, 2)
        forecast_14d = round(price_usd * 0.91, 2)

    # Action recommendation
    if label == PriceLabel.STEAL:
        action = ActionType.BUY_NOW
        reason = (
            f"This price is in the bottom {percentile}% of fares we've recorded on this route. "
            f"The historical average is ${median:,.0f}. Prices are trending {trend.value.lower()} — act now."
        )
    elif label == PriceLabel.GREAT_DEAL and trend == PriceTrend.RISING:
        action = ActionType.BUY_NOW
        reason = (
            f"A genuinely good deal — {savings_pct:.0f}% below the historical average of ${median:,.0f}. "
            f"Prices are rising, so this window won't last."
        )
    elif label == PriceLabel.GREAT_DEAL:
        action = ActionType.BUY_NOW
        reason = (
            f"This is a solid price — ${savings_vs_median:,.0f} below the typical fare on this route. "
            f"Safe to book now."
        )
    elif label == PriceLabel.FAIR and trend == PriceTrend.FALLING:
        action = ActionType.WAIT
        reason = (
            f"Price is near the historical average but trending down. "
            f"We expect it to drop to around ${forecast_14d:,.0f} in the next two weeks."
        )
    elif label in (PriceLabel.EXPENSIVE, PriceLabel.OVERPRICED) and days_out < 7:
        action = ActionType.BUY_NOW
        reason = (
            f"Departure is soon — prices rarely improve this close to the flight date. "
            f"Book now to secure your seat."
        )
    elif label in (PriceLabel.EXPENSIVE, PriceLabel.OVERPRICED):
        action = ActionType.SET_ALERT
        reason = (
            f"This price is above the historical average of ${median:,.0f}. "
            f"Set an alert — we'll notify you the moment it drops."
        )
    else:
        action = ActionType.MONITOR
        reason = "Price is in line with historical averages. We'll keep watching for a better deal."

    return PriceIntelligence(
        price_label=label,
        price_percentile=percentile,
        savings_vs_median_usd=savings_vs_median if savings_vs_median > 0 else None,
        savings_pct=savings_pct,
        trend=trend,
        forecast_7d_usd=forecast_7d,
        forecast_14d_usd=forecast_14d,
        action=action,
        action_reason=reason,
        badge_text=badge,
        confidence=confidence,
    )


# ── Offer Generator ───────────────────────────────────────────────────────────

def _seeded_random(seed: str) -> random.Random:
    """Deterministic random from a string seed — same inputs → same mock results."""
    h = int(hashlib.md5(seed.encode()).hexdigest(), 16)
    return random.Random(h)


def _make_segment(
    origin: str, destination: str, departure_dt: datetime,
    carrier: str, flight_num: str, duration_min: int,
    cabin: CabinClass, aircraft: str,
) -> Segment:
    arrival_dt = departure_dt + timedelta(minutes=duration_min)
    return Segment(
        origin=origin,
        destination=destination,
        departure_at=departure_dt,
        arrival_at=arrival_dt,
        carrier_code=carrier,
        flight_number=flight_num,
        aircraft_code=aircraft,
        duration_minutes=duration_min,
        cabin=cabin,
    )


def _make_offer(
    origin: str, destination: str,
    departure_dt: datetime, return_dt: Optional[datetime],
    carrier: str, flight_num: str,
    duration_min: int, stops: int,
    price: float, cabin: CabinClass,
    route: dict, days_out: int,
    rng: random.Random,
    adults: int,
    trip_type: TripType,
    layover_hub: Optional[str] = None,
    aircraft: Optional[str] = None,
) -> FlightOffer:

    if aircraft is None:
        aircraft = rng.choice(AIRCRAFT)

    # Build outbound itinerary
    if stops == 0:
        outbound_segments = [
            _make_segment(origin, destination, departure_dt, carrier,
                          flight_num, duration_min, cabin, aircraft)
        ]
    else:
        hub = layover_hub or rng.choice(["ORD", "ATL", "LAX", "FRA", "ICN"])
        leg1_dur = int(duration_min * rng.uniform(0.35, 0.50))
        layover_dur = rng.randint(60, 180)
        leg2_dur = duration_min - leg1_dur
        hub_dep = departure_dt + timedelta(minutes=leg1_dur + layover_dur)

        fn_suffix = rng.randint(100, 9999)
        outbound_segments = [
            _make_segment(origin, hub, departure_dt, carrier,
                          flight_num, leg1_dur, cabin, aircraft),
            _make_segment(hub, destination, hub_dep, carrier,
                          f"{carrier}{fn_suffix}", leg2_dur, cabin, aircraft),
        ]

    outbound = Itinerary(
        segments=outbound_segments,
        total_duration_minutes=duration_min,
        stops=stops,
    )
    itineraries = [outbound]

    # Build return itinerary for roundtrips
    if trip_type == TripType.ROUNDTRIP and return_dt:
        return_dep = return_dt.replace(
            hour=rng.randint(7, 21), minute=rng.choice([0, 15, 30, 45])
        )
        ret_dur = int(duration_min * rng.uniform(0.95, 1.10))
        ret_fn = f"{carrier}{rng.randint(100, 9999)}"

        if stops == 0:
            ret_segments = [
                _make_segment(destination, origin, return_dep, carrier,
                              ret_fn, ret_dur, cabin, aircraft)
            ]
        else:
            hub = layover_hub or rng.choice(["ORD", "ATL", "LAX", "FRA", "ICN"])
            ret_leg1 = int(ret_dur * rng.uniform(0.35, 0.50))
            ret_layover = rng.randint(60, 180)
            ret_leg2 = ret_dur - ret_leg1
            ret_hub_dep = return_dep + timedelta(minutes=ret_leg1 + ret_layover)
            ret_fn2 = f"{carrier}{rng.randint(100, 9999)}"
            ret_segments = [
                _make_segment(destination, hub, return_dep, carrier,
                              ret_fn, ret_leg1, cabin, aircraft),
                _make_segment(hub, origin, ret_hub_dep, carrier,
                              ret_fn2, ret_leg2, cabin, aircraft),
            ]

        itineraries.append(Itinerary(
            segments=ret_segments,
            total_duration_minutes=ret_dur,
            stops=stops,
        ))

    # Price breakdown
    base = round(price * 0.82, 2)
    taxes = round(price - base, 2)
    per_adult = round(price / adults, 2) if adults > 1 else None

    # Baggage
    bags = 1 if cabin in (CabinClass.ECONOMY, CabinClass.PREMIUM_ECONOMY) else 2
    bag_weight = 23 if cabin == CabinClass.ECONOMY else 32

    # Fare conditions
    is_refundable = rng.random() > 0.7
    change_fee = None if is_refundable else rng.choice([150.0, 200.0, 250.0, 300.0])

    # Seats remaining
    seats = rng.choice([None, 2, 3, 4, 5, 7, 9, None, None])

    price_intel = _compute_price_intelligence(price, route, days_out)

    return FlightOffer(
        offer_id=str(uuid.uuid4()),
        source="mock",
        itineraries=itineraries,
        price=PriceBreakdown(
            total_usd=price,
            base_fare_usd=base,
            taxes_usd=taxes,
            per_adult_usd=per_adult,
        ),
        baggage=BaggageInfo(
            checked_bags_included=bags,
            carry_on_included=True,
            checked_bag_weight_kg=bag_weight,
        ),
        fare_conditions=FareConditions(
            is_refundable=is_refundable,
            change_fee_usd=change_fee,
            fare_class=rng.choice(["V", "K", "L", "Q", "N", "M", "B", "Y"]),
        ),
        seats_remaining=seats,
        price_intelligence=price_intel,
        booking_url=None,
    )


# ── Public API ────────────────────────────────────────────────────────────────

def generate_mock_offers(req: SearchRequest) -> list[FlightOffer]:
    """
    Generate a realistic set of mock flight offers for a given SearchRequest.
    Results are deterministic for the same input (same seed → same results),
    which makes UI development and testing consistent.
    """
    origin = req.origin.upper()
    destination = req.destination.upper()

    route_key = frozenset({origin, destination})
    route = ROUTE_DB.get(route_key, DEFAULT_ROUTE)

    seed = f"{origin}{destination}{req.departure_date.isoformat()}{req.cabin_class.value}"
    rng = _seeded_random(seed)

    today = req.departure_date  # use departure as "today" for days_out calc
    from datetime import date
    days_out = (req.departure_date - date.today()).days

    # Adjust price range for cabin class
    cabin_multipliers = {
        CabinClass.ECONOMY: 1.0,
        CabinClass.PREMIUM_ECONOMY: 1.8,
        CabinClass.BUSINESS: 3.5,
        CabinClass.FIRST: 6.0,
    }
    multiplier = cabin_multipliers.get(req.cabin_class, 1.0)

    price_min = route["price_min"] * multiplier
    price_median = route["price_median"] * multiplier
    price_max = route["price_max"] * multiplier

    # Cabin for segments
    cabin = req.cabin_class

    # Departure times spread through the day
    dep_times_direct = [
        req.departure_date, req.departure_date, req.departure_date,
    ]
    dep_hours_direct = [7, 11, 15]
    dep_hours_1stop = [6, 9, 14, 19]

    offers: list[FlightOffer] = []

    # ── Direct flights ──────────────────────────────────────────────────────
    for i, (carrier, dep_hour) in enumerate(
        zip(route["airlines_direct"], dep_hours_direct[:len(route["airlines_direct"])])
    ):
        if req.non_stop_only or True:  # always include direct if available
            dep_dt = datetime(
                req.departure_date.year, req.departure_date.month, req.departure_date.day,
                dep_hour, rng.choice([0, 15, 30, 45]),
                tzinfo=timezone.utc,
            )
            duration = rng.randint(route["duration_min"], route["duration_max"])
            # Direct flights command a premium (5–15% above cheapest 1-stop)
            price_raw = rng.uniform(price_min * 1.05, price_median * 1.10)
            price = round(price_raw * req.adults, 2)
            fn = f"{carrier}{rng.randint(1, 999):03d}"
            aircraft = rng.choice(["Boeing 787-9", "Boeing 777-300ER", "Airbus A350-900"])
            ret_dt = req.return_date

            offers.append(_make_offer(
                origin, destination, dep_dt, ret_dt,
                carrier, fn, duration, 0, price, cabin,
                route, days_out, rng, req.adults, req.trip_type,
                aircraft=aircraft,
            ))

    # ── 1-stop flights ──────────────────────────────────────────────────────
    if not req.non_stop_only:
        layover_hubs = route.get("layover_hubs_1stop", ["ORD", "ATL"])
        for i, carrier in enumerate(route["airlines_1stop"]):
            dep_hour = dep_hours_1stop[i % len(dep_hours_1stop)]
            dep_dt = datetime(
                req.departure_date.year, req.departure_date.month, req.departure_date.day,
                dep_hour, rng.choice([0, 30]),
                tzinfo=timezone.utc,
            )
            # 1-stop flights are 20–40% longer total due to layover
            base_dur = rng.randint(route["duration_min"], route["duration_max"])
            duration = base_dur + rng.randint(90, 240)  # add layover
            # 1-stop flights are typically cheaper
            price_raw = rng.uniform(price_min * 0.85, price_median * 0.92)
            price = round(price_raw * req.adults, 2)
            fn = f"{carrier}{rng.randint(1, 999):03d}"
            hub = layover_hubs[i % len(layover_hubs)] if layover_hubs else "ORD"
            ret_dt = req.return_date

            offers.append(_make_offer(
                origin, destination, dep_dt, ret_dt,
                carrier, fn, duration, 1, price, cabin,
                route, days_out, rng, req.adults, req.trip_type,
                layover_hub=hub,
            ))

        # Add one "budget" 1-stop with very low price (STEAL territory)
        if rng.random() > 0.3:
            budget_carrier = rng.choice(route["airlines_1stop"] or route["airlines_direct"] or ["UA"])
            dep_dt = datetime(
                req.departure_date.year, req.departure_date.month, req.departure_date.day,
                22, 30, tzinfo=timezone.utc,  # late night / red-eye
            )
            duration = rng.randint(route["duration_min"] + 120, route["duration_max"] + 300)
            price_raw = rng.uniform(price_min * 0.72, price_min * 0.95)
            price = round(price_raw * req.adults, 2)
            fn = f"{budget_carrier}{rng.randint(1, 999):03d}"
            hub = route.get("layover_hubs_1stop", ["ORD"])[0]
            ret_dt = req.return_date

            offers.append(_make_offer(
                origin, destination, dep_dt, ret_dt,
                budget_carrier, fn, duration, 1, price, cabin,
                route, days_out, rng, req.adults, req.trip_type,
                layover_hub=hub,
            ))

    # Sort by price ascending
    offers.sort(key=lambda o: o.price.total_usd)
    return offers[:req.max_results]
