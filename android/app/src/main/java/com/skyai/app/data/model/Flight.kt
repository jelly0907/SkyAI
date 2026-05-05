package com.skyai.app.data.model

import com.google.gson.annotations.SerializedName

// ===== Enums =====
//
// All wire values mirror backend Pydantic enums (see backend/models.py). When
// the backend ships UPPERCASE strings, so do we — Gson's @SerializedName is
// case-sensitive and bare property names default to camelCase, so omitting
// the annotation here would silently break parsing.

// CabinClass uses UPPERCASE wire values (matches backend models.py:
// `class CabinClass(str, Enum): ECONOMY = "ECONOMY" ...`). The previous
// lowercase variants were producing 422s on POST /search/flights.
enum class CabinClass {
    @SerializedName("ECONOMY")
    ECONOMY,
    @SerializedName("PREMIUM_ECONOMY")
    PREMIUM_ECONOMY,
    @SerializedName("BUSINESS")
    BUSINESS,
    @SerializedName("FIRST")
    FIRST
}

enum class TripType {
    @SerializedName("roundtrip")
    ROUNDTRIP,
    @SerializedName("one_way")
    ONE_WAY,
    @SerializedName("multi_city")
    MULTI_CITY
}

enum class PriceLabel {
    @SerializedName("STEAL")
    STEAL,
    @SerializedName("GREAT_DEAL")
    GREAT_DEAL,
    @SerializedName("FAIR")
    FAIR,
    @SerializedName("EXPENSIVE")
    EXPENSIVE,
    @SerializedName("OVERPRICED")
    OVERPRICED,
    @SerializedName("UNKNOWN")
    UNKNOWN
}

enum class PriceTrend {
    @SerializedName("RISING")
    RISING,
    @SerializedName("FALLING")
    FALLING,
    @SerializedName("STABLE")
    STABLE,
    @SerializedName("VOLATILE")
    VOLATILE
}

enum class ActionType {
    @SerializedName("BUY_NOW")
    BUY_NOW,
    @SerializedName("WAIT")
    WAIT,
    @SerializedName("SET_ALERT")
    SET_ALERT,
    @SerializedName("MONITOR")
    MONITOR
}

// ===== Request/Response DTOs =====

/**
 * Mirrors backend `class SearchRequest(BaseModel)` in backend/models.py.
 * Field names below MUST match the Pydantic model exactly when serialized,
 * so each property carries an explicit @SerializedName. Don't add Kotlin
 * properties without a corresponding `@SerializedName` — Gson will encode
 * them in camelCase and the backend will 422 the request.
 */
data class SearchRequest(
    @SerializedName("origin")
    val origin: String,
    @SerializedName("destination")
    val destination: String,
    @SerializedName("departure_date")
    val departureDate: String,
    @SerializedName("return_date")
    val returnDate: String? = null,
    @SerializedName("adults")
    val adults: Int = 1,
    @SerializedName("children")
    val children: Int = 0,
    @SerializedName("infants")
    val infants: Int = 0,
    @SerializedName("cabin_class")
    val cabinClass: CabinClass = CabinClass.ECONOMY,
    @SerializedName("trip_type")
    val tripType: TripType = TripType.ROUNDTRIP,
    @SerializedName("max_results")
    val maxResults: Int = 20,
    // Backend field is `non_stop_only`. The previous wire name `direct_only`
    // was silently dropped on the server, which is why non-stop toggles in
    // the Android UI had no effect on results.
    @SerializedName("non_stop_only")
    val nonStopOnly: Boolean = false
)

data class IntentRequest(
    @SerializedName("query")
    val query: String
)

/**
 * Mirrors backend `class IntentResponse(BaseModel)`. The backend wire name
 * is `search_request` (not `parsed_request` — that was an inherited bug;
 * Gson would silently leave `parsedRequest` null).
 */
data class IntentResponse(
    @SerializedName("search_request")
    val searchRequest: SearchRequest,
    @SerializedName("confidence")
    val confidence: Float,
    @SerializedName("raw_query")
    val rawQuery: String,
    @SerializedName("interpretation")
    val interpretation: String
)

// ===== Response Models =====
//
// Stored properties + @SerializedName mirror the backend Pydantic schema
// exactly (see backend/models.py). Legacy Kotlin field names from earlier
// scaffold versions are preserved as computed properties (`val foo get() =
// ...`) so UI code (FlightCard, FlightDetailScreen, ParetoBar, etc.) keeps
// compiling without changes. Gson never sees the computed-property aliases.

/**
 * One leg of a flight (one takeoff → one landing). Mirrors backend Segment.
 * `departureAt` / `arrivalAt` arrive as ISO-8601 strings; the UI parses them
 * with `Instant.parse(...)` at render time, so we keep them as Strings here.
 */
data class Segment(
    @SerializedName("origin")
    val origin: String,
    @SerializedName("destination")
    val destination: String,
    @SerializedName("departure_at")
    val departureAt: String,
    @SerializedName("arrival_at")
    val arrivalAt: String,
    @SerializedName("carrier_code")
    val carrierCode: String,
    @SerializedName("flight_number")
    val flightNumber: String,
    @SerializedName("aircraft_code")
    val aircraftCode: String? = null,
    @SerializedName("duration_minutes")
    val durationMinutes: Int,
    @SerializedName("cabin")
    val cabin: CabinClass = CabinClass.ECONOMY
) {
    // ── Legacy aliases used throughout the UI ────────────────────────────
    val departureAirport: String get() = origin
    val arrivalAirport: String get() = destination
    val departureTime: String get() = departureAt
    val arrivalTime: String get() = arrivalAt
    val airline: String get() = carrierCode
    val aircraft: String get() = aircraftCode ?: ""
    // Backend Segment has no per-segment `stops` field (stops live on
    // Itinerary). Keeping this as 0 lets the existing UI loops compile.
    val stops: Int get() = 0
}

data class Itinerary(
    @SerializedName("segments")
    val segments: List<Segment>,
    @SerializedName("total_duration_minutes")
    val totalDurationMinutes: Int,
    @SerializedName("stops")
    val stops: Int = 0
) {
    // Legacy alias.
    val durationMinutes: Int get() = totalDurationMinutes
}

data class PriceBreakdown(
    @SerializedName("total_usd")
    val totalUsd: Double,
    @SerializedName("base_fare_usd")
    val baseFareUsd: Double,
    @SerializedName("taxes_usd")
    val taxesUsd: Double,
    @SerializedName("fees_usd")
    val feesUsd: Double = 0.0,
    @SerializedName("per_adult_usd")
    val perAdultUsd: Double? = null
) {
    // ── Legacy aliases ───────────────────────────────────────────────────
    val total: Double get() = totalUsd
    val baseFare: Double get() = baseFareUsd
    val basePrice: Double get() = baseFareUsd
    val taxes: Double get() = taxesUsd
    val fees: Double get() = feesUsd
}

data class BaggageInfo(
    @SerializedName("checked_bags_included")
    val checkedBagsIncluded: Int = 0,
    @SerializedName("carry_on_included")
    val carryOnIncluded: Boolean = true,
    @SerializedName("checked_bag_weight_kg")
    val checkedBagWeightKg: Int? = null
) {
    // ── Legacy aliases ───────────────────────────────────────────────────
    // FlightDetailScreen passes `checkedBags` to a Composable that expects
    // a String, so we surface it as a String here. Numeric callers should
    // read `checkedBagsIncluded` directly.
    val checkedBags: String get() = checkedBagsIncluded.toString()
    val carryOn: String get() = if (carryOnIncluded) "1 carry-on included" else "Not included"
}

data class FareConditions(
    @SerializedName("is_refundable")
    val isRefundable: Boolean = false,
    @SerializedName("change_fee_usd")
    val changeFeeUsd: Double? = null,
    @SerializedName("fare_class")
    val fareClass: String? = null
) {
    // ── Legacy aliases ───────────────────────────────────────────────────
    val refundable: Boolean get() = isRefundable
    // `changeable` is true if the backend supplies a change fee at all
    // (even $0); null means change-policy unknown. Matches iOS.
    val changeable: Boolean get() = changeFeeUsd != null
    // Old scaffold had this; backend doesn't surface it. Kept as a constant
    // so the UI doesn't error if it ever reads it.
    val seatSelectionIncluded: Boolean get() = false
}

data class PriceIntelligence(
    @SerializedName("price_label")
    val priceLabel: PriceLabel = PriceLabel.UNKNOWN,
    @SerializedName("price_percentile")
    val pricePercentile: Int? = null,
    @SerializedName("savings_vs_median_usd")
    val savingsVsMedianUsd: Double? = null,
    @SerializedName("savings_pct")
    val savingsPct: Double? = null,
    @SerializedName("trend")
    val trend: PriceTrend = PriceTrend.STABLE,
    @SerializedName("forecast_7d_usd")
    val forecast7dUsd: Double? = null,
    @SerializedName("forecast_14d_usd")
    val forecast14dUsd: Double? = null,
    @SerializedName("action")
    val action: ActionType = ActionType.MONITOR,
    @SerializedName("action_reason")
    val actionReason: String = "",
    @SerializedName("badge_text")
    val badgeText: String = "",
    @SerializedName("confidence")
    val confidence: Double = 0.0
) {
    // ── Legacy aliases ───────────────────────────────────────────────────
    // Existing UI code expects `percentile` as a non-null Int and uses it
    // for `progress = percentile / 100f` and "Cheaper than X% of fares"
    // copy. Backend ships `price_percentile: Int | null`, so default to 50
    // (median) when missing — keeps the progress bar centered.
    val percentile: Int get() = pricePercentile ?: 50
    val predicted7d: Double? get() = forecast7dUsd
    val predicted14d: Double? get() = forecast14dUsd
    val actionType: ActionType get() = action
}

data class FlightOffer(
    @SerializedName("offer_id")
    val offerId: String,
    @SerializedName("source")
    val source: String = "",
    @SerializedName("itineraries")
    val itineraries: List<Itinerary>,
    // Backend wire key is "price" (not "price_breakdown"). Keep the Kotlin
    // property name as `price` so existing `offer.price.total` call sites
    // work; legacy `priceBreakdown` is exposed as a computed alias.
    @SerializedName("price")
    val price: PriceBreakdown,
    // Wire key is "baggage"; UI reads it as `offer.baggageInfo`.
    @SerializedName("baggage")
    val baggage: BaggageInfo = BaggageInfo(),
    @SerializedName("fare_conditions")
    val fareConditions: FareConditions = FareConditions(),
    @SerializedName("seats_remaining")
    val seatsRemaining: Int? = null,
    @SerializedName("price_intelligence")
    val priceIntelligence: PriceIntelligence = PriceIntelligence(),
    @SerializedName("booking_url")
    val bookingUrl: String? = null,
    @SerializedName("last_ticketing_date")
    val lastTicketingDate: String? = null
) {
    // ── Identifiable / legacy aliases ────────────────────────────────────
    val id: String get() = offerId

    /** First slice — outbound leg of the trip. */
    val outboundItinerary: Itinerary
        get() = itineraries.firstOrNull()
            ?: Itinerary(segments = emptyList(), totalDurationMinutes = 0, stops = 0)

    /** Optional second slice — inbound (return) leg. Null for one-ways. */
    val returnItinerary: Itinerary? get() = itineraries.getOrNull(1)

    val baggageInfo: BaggageInfo get() = baggage

    // Backend now nests fare_class under fare_conditions.
    val fareClass: String get() = fareConditions.fareClass ?: ""

    /** Total stops summed across every itinerary in the offer. */
    val totalStops: Int get() = itineraries.sumOf { it.stops }
}

data class SearchResponse(
    @SerializedName("query_id")
    val queryId: String,
    @SerializedName("search_request")
    val searchRequest: SearchRequest,
    @SerializedName("offers")
    val offers: List<FlightOffer>,
    @SerializedName("total_found")
    val totalFound: Int = 0,
    @SerializedName("sources_queried")
    val sourcesQueried: List<String> = emptyList(),
    @SerializedName("returned_at")
    val returnedAt: String,
    @SerializedName("currency")
    val currency: String = "USD"
) {
    // ── Legacy aliases ───────────────────────────────────────────────────
    // Top-level route fields used to live on SearchResponse directly; the
    // backend now nests them under `search_request`. Expose flattened
    // accessors so ResultsScreen's `searchResponse.origin` etc. keep working.
    val searchId: String get() = queryId
    val origin: String get() = searchRequest.origin
    val destination: String get() = searchRequest.destination
    val departureDate: String get() = searchRequest.departureDate
    val returnDate: String? get() = searchRequest.returnDate
    val searchCompletedAt: String get() = returnedAt
}
