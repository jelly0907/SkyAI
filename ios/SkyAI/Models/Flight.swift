import Foundation

// MARK: - Enums

enum CabinClass: String, Codable, CaseIterable, Hashable {
    // Wire values are UPPERCASE to match backend Pydantic CabinClass
    // (see backend/models.py). Swift case names stay camelCase.
    case economy = "ECONOMY"
    case premiumEconomy = "PREMIUM_ECONOMY"
    case business = "BUSINESS"
    case first = "FIRST"

    var displayName: String {
        switch self {
        case .economy:
            return "Economy"
        case .premiumEconomy:
            return "Premium Economy"
        case .business:
            return "Business"
        case .first:
            return "First"
        }
    }
}

enum TripType: String, Codable, CaseIterable, Hashable {
    case roundtrip
    case oneWay = "one_way"
    case multiCity = "multi_city"

    var displayName: String {
        switch self {
        case .roundtrip:
            return "Round Trip"
        case .oneWay:
            return "One Way"
        case .multiCity:
            return "Multi-City"
        }
    }
}

enum PriceLabel: String, Codable {
    // Wire values UPPERCASE to match backend Pydantic PriceLabel.
    case steal = "STEAL"
    case greatDeal = "GREAT_DEAL"
    case fair = "FAIR"
    case expensive = "EXPENSIVE"
    case overpriced = "OVERPRICED"
    case unknown = "UNKNOWN"

    var displayName: String {
        switch self {
        case .steal:
            return "STEAL"
        case .greatDeal:
            return "GREAT DEAL"
        case .fair:
            return "FAIR"
        case .expensive:
            return "EXPENSIVE"
        case .overpriced:
            return "OVERPRICED"
        case .unknown:
            return "UNKNOWN"
        }
    }

    var badgeColor: String {
        switch self {
        case .steal:
            return "#FF6B35"
        case .greatDeal:
            return "#22C55E"
        case .fair:
            return "#9CA3AF"
        case .expensive:
            return "#F59E0B"
        case .overpriced:
            return "#EF4444"
        case .unknown:
            return "#D1D5DB"
        }
    }
}

enum PriceTrend: String, Codable {
    // Wire values UPPERCASE to match backend Pydantic PriceTrend.
    case rising = "RISING"
    case falling = "FALLING"
    case stable = "STABLE"
    case volatile = "VOLATILE"
}

enum ActionType: String, Codable {
    // Wire values UPPERCASE to match backend Pydantic ActionType.
    case buyNow = "BUY_NOW"
    case wait = "WAIT"
    case setAlert = "SET_ALERT"
    case monitor = "MONITOR"
}

// MARK: - Requests & Responses

struct IntentRequest: Codable {
    let query: String
}

struct IntentResponse: Codable {
    let searchRequest: SearchRequest
    let interpretation: String
    let confidence: Double

    enum CodingKeys: String, CodingKey {
        case searchRequest = "search_request"
        case interpretation
        case confidence
    }
}

struct SearchRequest: Codable, Equatable, Hashable {
    var originCode: String
    var destinationCode: String
    var departureDate: Date
    var returnDate: Date?
    var adults: Int
    var children: Int
    var infants: Int
    var cabinClass: CabinClass
    var tripType: TripType
    var directFlightsOnly: Bool
    var maxStops: Int?

    enum CodingKeys: String, CodingKey {
        // Wire format matches backend Pydantic SearchRequest (see backend/models.py).
        // Swift property names stay camelCase for readability; only JSON keys change.
        case originCode = "origin"
        case destinationCode = "destination"
        case departureDate = "departure_date"
        case returnDate = "return_date"
        case adults
        case children
        case infants
        case cabinClass = "cabin_class"
        case tripType = "trip_type"
        case directFlightsOnly = "non_stop_only"
        case maxStops = "max_stops"
    }

    init(
        originCode: String = "",
        destinationCode: String = "",
        departureDate: Date = Date().addingTimeInterval(86400),
        returnDate: Date? = nil,
        adults: Int = 1,
        children: Int = 0,
        infants: Int = 0,
        cabinClass: CabinClass = .economy,
        tripType: TripType = .roundtrip,
        directFlightsOnly: Bool = false,
        maxStops: Int? = nil
    ) {
        self.originCode = originCode
        self.destinationCode = destinationCode
        self.departureDate = departureDate
        self.returnDate = returnDate ?? Calendar.current.date(byAdding: .day, value: 30, to: departureDate)
        self.adults = adults
        self.children = children
        self.infants = infants
        self.cabinClass = cabinClass
        self.tripType = tripType
        self.directFlightsOnly = directFlightsOnly
        self.maxStops = maxStops
    }
}

// MARK: - Response Models
//
// Stored properties mirror the backend Pydantic schema exactly (see
// backend/models.py). Legacy Swift property names from earlier iOS
// versions are preserved as computed properties so UI code keeps
// compiling unchanged.

struct Segment: Codable {
    let origin: String
    let destination: String
    let departureAt: Date
    let arrivalAt: Date
    let carrierCode: String
    let flightNumber: String
    let aircraftCode: String?
    let durationMinutes: Int
    let cabin: CabinClass

    enum CodingKeys: String, CodingKey {
        case origin
        case destination
        case departureAt = "departure_at"
        case arrivalAt = "arrival_at"
        case carrierCode = "carrier_code"
        case flightNumber = "flight_number"
        case aircraftCode = "aircraft_code"
        case durationMinutes = "duration_minutes"
        case cabin
    }

    // Legacy API used by existing UI code.
    var departureAirport: String { origin }
    var arrivalAirport: String { destination }
    var departureTime: Date { departureAt }
    var arrivalTime: Date { arrivalAt }
    var airlineCode: String { carrierCode }
    var aircraft: String? { aircraftCode }
    // Backend Segment has no `stops` (stops live on Itinerary); UI still
    // reads this per-segment in a couple of places — keep it as 0.
    var stops: Int { 0 }

    var formattedDuration: String {
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct Itinerary: Codable {
    let segments: [Segment]
    let totalDurationMinutes: Int
    let stops: Int

    enum CodingKeys: String, CodingKey {
        case segments
        case totalDurationMinutes = "total_duration_minutes"
        case stops
    }

    // Legacy name used by UI.
    var durationMinutes: Int { totalDurationMinutes }

    var formattedDuration: String {
        let hours = totalDurationMinutes / 60
        let minutes = totalDurationMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var totalStops: Int { stops }
}

struct PriceBreakdown: Codable {
    let totalUsd: Double
    let baseFareUsd: Double
    let taxesUsd: Double
    let feesUsd: Double
    let perAdultUsd: Double?

    enum CodingKeys: String, CodingKey {
        case totalUsd = "total_usd"
        case baseFareUsd = "base_fare_usd"
        case taxesUsd = "taxes_usd"
        case feesUsd = "fees_usd"
        case perAdultUsd = "per_adult_usd"
    }

    // Legacy API.
    var basePrice: Double { baseFareUsd }
    var taxes: Double { taxesUsd }
    var fees: Double { feesUsd }
    var total: Double { totalUsd }
}

struct BaggageInfo: Codable {
    let checkedBagsIncluded: Int
    let carryOnIncluded: Bool
    let checkedBagWeightKg: Int?

    enum CodingKeys: String, CodingKey {
        case checkedBagsIncluded = "checked_bags_included"
        case carryOnIncluded = "carry_on_included"
        case checkedBagWeightKg = "checked_bag_weight_kg"
    }

    // Legacy API — UI expects these shapes.
    var carryon: String { carryOnIncluded ? "1 carry-on included" : "Not included" }
    var checkedBags: Int { checkedBagsIncluded }
    var checkedWeight: String? { checkedBagWeightKg.map { "\($0) kg" } }
}

struct FareConditions: Codable {
    let isRefundable: Bool
    let changeFeeUsd: Double?
    let fareClass: String?

    enum CodingKeys: String, CodingKey {
        case isRefundable = "is_refundable"
        case changeFeeUsd = "change_fee_usd"
        case fareClass = "fare_class"
    }

    // Legacy API. `changeable` is true if backend supplies a change fee
    // (even $0), false if the fee is unspecified/nil.
    var refundable: Bool { isRefundable }
    var changeable: Bool { changeFeeUsd != nil }
    var minStayDays: Int? { nil }
}

struct PriceIntelligence: Codable {
    let priceLabel: PriceLabel
    let pricePercentile: Int?
    let savingsVsMedianUsd: Double?
    let savingsPct: Double?
    let trend: PriceTrend
    let forecast7dUsd: Double?
    let forecast14dUsd: Double?
    let action: ActionType
    let actionReason: String
    let badgeText: String
    let confidence: Double

    enum CodingKeys: String, CodingKey {
        case priceLabel = "price_label"
        case pricePercentile = "price_percentile"
        case savingsVsMedianUsd = "savings_vs_median_usd"
        case savingsPct = "savings_pct"
        case trend
        case forecast7dUsd = "forecast_7d_usd"
        case forecast14dUsd = "forecast_14d_usd"
        case action
        case actionReason = "action_reason"
        case badgeText = "badge_text"
        case confidence
    }

    // Legacy API — mapped to new fields so UI keeps working.
    var percentileRank: Double { Double(pricePercentile ?? 50) / 100.0 }
    var savingsAmount: Double? { savingsVsMedianUsd }
    var savingsPercent: Double? { savingsPct }
    var recommendedAction: ActionType { action }
    var explanation: String { actionReason }
    // Backend no longer sends these; kept nil for UI compatibility.
    var historicalAverage: Double? { nil }
    var historicalMin: Double? { nil }
    var historicalMax: Double? { nil }
}

struct FlightOffer: Codable, Identifiable {
    let offerId: String
    let source: String
    let itineraries: [Itinerary]
    let priceBreakdown: PriceBreakdown     // decoded from backend "price"
    let baggageInfo: BaggageInfo           // decoded from backend "baggage"
    let fareConditions: FareConditions
    let seatsRemaining: Int?
    let priceIntelligence: PriceIntelligence
    let bookingUrl: String?
    let lastTicketingDate: Date?

    enum CodingKeys: String, CodingKey {
        case offerId = "offer_id"
        case source
        case itineraries
        case priceBreakdown = "price"
        case baggageInfo = "baggage"
        case fareConditions = "fare_conditions"
        case seatsRemaining = "seats_remaining"
        case priceIntelligence = "price_intelligence"
        case bookingUrl = "booking_url"
        case lastTicketingDate = "last_ticketing_date"
    }

    // Identifiable conformance.
    var id: String { offerId }

    // Legacy API.
    var outbound: Itinerary {
        itineraries.first ?? Itinerary(segments: [], totalDurationMinutes: 0, stops: 0)
    }
    var inbound: Itinerary? {
        itineraries.count > 1 ? itineraries[1] : nil
    }
    var availableSeats: Int { seatsRemaining ?? 0 }

    // UI helpers (signature unchanged).
    var totalDuration: String {
        let totalMinutes = outbound.durationMinutes + (inbound?.durationMinutes ?? 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var totalStops: Int {
        itineraries.reduce(0) { $0 + $1.stops }
    }

    var priceLabel: String {
        priceIntelligence.priceLabel.displayName
    }

    var price: Double {
        priceBreakdown.totalUsd
    }
}

struct SearchResponse: Codable {
    let queryId: String
    let searchRequest: SearchRequest
    let offers: [FlightOffer]
    let totalFound: Int
    let sourcesQueried: [String]
    let returnedAt: Date
    let currency: String

    enum CodingKeys: String, CodingKey {
        case queryId = "query_id"
        case searchRequest = "search_request"
        case offers
        case totalFound = "total_found"
        case sourcesQueried = "sources_queried"
        case returnedAt = "returned_at"
        case currency
    }

    // Legacy name.
    var searchTimestamp: Date { returnedAt }
}
