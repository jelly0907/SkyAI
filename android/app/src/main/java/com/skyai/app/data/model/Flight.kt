package com.skyai.app.data.model

import com.google.gson.annotations.SerializedName
import java.time.LocalDateTime
import java.time.LocalDate

// ===== Enums =====

enum class CabinClass {
    @SerializedName("economy")
    ECONOMY,
    @SerializedName("premium_economy")
    PREMIUM_ECONOMY,
    @SerializedName("business")
    BUSINESS,
    @SerializedName("first")
    FIRST
}

enum class TripType {
    @SerializedName("roundtrip")
    ROUNDTRIP,
    @SerializedName("one_way")
    ONE_WAY
}

enum class PriceLabel {
    @SerializedName("UNKNOWN")
    UNKNOWN,
    @SerializedName("STEAL")
    STEAL,
    @SerializedName("GREAT_DEAL")
    GREAT_DEAL,
    @SerializedName("FAIR")
    FAIR
}

enum class PriceTrend {
    @SerializedName("up")
    UP,
    @SerializedName("down")
    DOWN,
    @SerializedName("stable")
    STABLE
}

enum class ActionType {
    @SerializedName("BUY_NOW")
    BUY_NOW,
    @SerializedName("WAIT")
    WAIT,
    @SerializedName("SET_ALERT")
    SET_ALERT
}

// ===== Request/Response DTOs =====

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
    @SerializedName("direct_only")
    val directOnly: Boolean = false,
    @SerializedName("trip_type")
    val tripType: TripType = TripType.ROUNDTRIP
)

data class IntentRequest(
    @SerializedName("query")
    val query: String
)

data class IntentResponse(
    @SerializedName("parsed_request")
    val parsedRequest: SearchRequest,
    @SerializedName("interpretation")
    val interpretation: String,
    @SerializedName("confidence")
    val confidence: Float
)

// ===== Flight Details =====

data class Segment(
    @SerializedName("departure_airport")
    val departureAirport: String,
    @SerializedName("arrival_airport")
    val arrivalAirport: String,
    @SerializedName("departure_time")
    val departureTime: String,
    @SerializedName("arrival_time")
    val arrivalTime: String,
    @SerializedName("airline")
    val airline: String,
    @SerializedName("flight_number")
    val flightNumber: String,
    @SerializedName("aircraft")
    val aircraft: String,
    @SerializedName("duration_minutes")
    val durationMinutes: Int,
    @SerializedName("stops")
    val stops: Int = 0
)

data class Itinerary(
    @SerializedName("segments")
    val segments: List<Segment>,
    @SerializedName("total_duration_minutes")
    val totalDurationMinutes: Int
)

data class PriceBreakdown(
    @SerializedName("base_fare")
    val baseFare: Double,
    @SerializedName("taxes")
    val taxes: Double,
    @SerializedName("fees")
    val fees: Double,
    @SerializedName("total")
    val total: Double
)

data class BaggageInfo(
    @SerializedName("carry_on")
    val carryOn: String,
    @SerializedName("checked_bags")
    val checkedBags: String
)

data class FareConditions(
    @SerializedName("refundable")
    val refundable: Boolean,
    @SerializedName("changeable")
    val changeable: Boolean,
    @SerializedName("seat_selection_included")
    val seatSelectionIncluded: Boolean
)

data class PriceIntelligence(
    @SerializedName("percentile")
    val percentile: Int,
    @SerializedName("trend")
    val trend: PriceTrend,
    @SerializedName("predicted_7d")
    val predicted7d: Double? = null,
    @SerializedName("predicted_14d")
    val predicted14d: Double? = null,
    @SerializedName("price_label")
    val priceLabel: PriceLabel = PriceLabel.UNKNOWN,
    @SerializedName("action_type")
    val actionType: ActionType = ActionType.BUY_NOW,
    @SerializedName("action_reason")
    val actionReason: String
)

// ===== Main Flight Offer =====

data class FlightOffer(
    @SerializedName("id")
    val id: String,
    @SerializedName("outbound_itinerary")
    val outboundItinerary: Itinerary,
    @SerializedName("return_itinerary")
    val returnItinerary: Itinerary? = null,
    @SerializedName("price")
    val price: PriceBreakdown,
    @SerializedName("baggage_info")
    val baggageInfo: BaggageInfo,
    @SerializedName("fare_conditions")
    val fareConditions: FareConditions,
    @SerializedName("price_intelligence")
    val priceIntelligence: PriceIntelligence,
    @SerializedName("seats_remaining")
    val seatsRemaining: Int,
    @SerializedName("fare_class")
    val fareClass: String
)

data class SearchResponse(
    @SerializedName("search_id")
    val searchId: String,
    @SerializedName("origin")
    val origin: String,
    @SerializedName("destination")
    val destination: String,
    @SerializedName("departure_date")
    val departureDate: String,
    @SerializedName("return_date")
    val returnDate: String? = null,
    @SerializedName("offers")
    val offers: List<FlightOffer>,
    @SerializedName("search_completed_at")
    val searchCompletedAt: String,
    @SerializedName("currency")
    val currency: String = "USD"
)
