import Foundation

// MARK: - Enums

enum CabinClass: String, Codable, CaseIterable, Hashable {
    case economy
    case premiumEconomy = "premium_economy"
    case business
    case first

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
    case steal
    case greatDeal = "great_deal"
    case fair
    case expensive
    case overpriced
    case unknown

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
    case rising
    case falling
    case stable
    case volatile
}

enum ActionType: String, Codable {
    case buyNow = "buy_now"
    case wait
    case setAlert = "set_alert"
    case monitor
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
        case originCode = "origin_code"
        case destinationCode = "destination_code"
        case departureDate = "departure_date"
        case returnDate = "return_date"
        case adults
        case children
        case infants
        case cabinClass = "cabin_class"
        case tripType = "trip_type"
        case directFlightsOnly = "direct_flights_only"
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

struct Segment: Codable {
    let departureAirport: String
    let departureTime: Date
    let arrivalAirport: String
    let arrivalTime: Date
    let flightNumber: String
    let airlineCode: String
    let aircraft: String?
    let durationMinutes: Int
    let stops: Int

    enum CodingKeys: String, CodingKey {
        case departureAirport = "departure_airport"
        case departureTime = "departure_time"
        case arrivalAirport = "arrival_airport"
        case arrivalTime = "arrival_time"
        case flightNumber = "flight_number"
        case airlineCode = "airline_code"
        case aircraft
        case durationMinutes = "duration_minutes"
        case stops
    }

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
    let durationMinutes: Int

    enum CodingKeys: String, CodingKey {
        case segments
        case durationMinutes = "duration_minutes"
    }

    var formattedDuration: String {
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var totalStops: Int {
        segments.reduce(0) { $0 + $1.stops }
    }
}

struct PriceBreakdown: Codable {
    let basePrice: Double
    let taxes: Double
    let fees: Double
    let currency: String

    enum CodingKeys: String, CodingKey {
        case basePrice = "base_price"
        case taxes
        case fees
        case currency
    }

    var total: Double {
        basePrice + taxes + fees
    }
}

struct BaggageInfo: Codable {
    let carryon: String
    let checkedBags: Int
    let checkedWeight: String?

    enum CodingKeys: String, CodingKey {
        case carryon
        case checkedBags = "checked_bags"
        case checkedWeight = "checked_weight"
    }
}

struct FareConditions: Codable {
    let refundable: Bool
    let changeable: Bool
    let minStayDays: Int?

    enum CodingKeys: String, CodingKey {
        case refundable
        case changeable
        case minStayDays = "min_stay_days"
    }
}

struct PriceIntelligence: Codable {
    let priceLabel: PriceLabel
    let percentileRank: Double
    let historicalAverage: Double?
    let historicalMin: Double?
    let historicalMax: Double?
    let savingsAmount: Double?
    let savingsPercent: Double?
    let trend: PriceTrend
    let recommendedAction: ActionType
    let explanation: String

    enum CodingKeys: String, CodingKey {
        case priceLabel = "price_label"
        case percentileRank = "percentile_rank"
        case historicalAverage = "historical_average"
        case historicalMin = "historical_min"
        case historicalMax = "historical_max"
        case savingsAmount = "savings_amount"
        case savingsPercent = "savings_percent"
        case trend
        case recommendedAction = "recommended_action"
        case explanation
    }
}

struct FlightOffer: Codable, Identifiable {
    let id: String
    let outbound: Itinerary
    let inbound: Itinerary?
    let priceBreakdown: PriceBreakdown
    let baggageInfo: BaggageInfo
    let fareConditions: FareConditions
    let priceIntelligence: PriceIntelligence
    let bookingUrl: String?
    let availableSeats: Int

    enum CodingKeys: String, CodingKey {
        case id
        case outbound
        case inbound
        case priceBreakdown = "price_breakdown"
        case baggageInfo = "baggage_info"
        case fareConditions = "fare_conditions"
        case priceIntelligence = "price_intelligence"
        case bookingUrl = "booking_url"
        case availableSeats = "available_seats"
    }

    var totalDuration: String {
        let totalMinutes = (outbound.durationMinutes) + (inbound?.durationMinutes ?? 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var totalStops: Int {
        (outbound.totalStops) + (inbound?.totalStops ?? 0)
    }

    var priceLabel: String {
        priceIntelligence.priceLabel.displayName
    }

    var price: Double {
        priceBreakdown.total
    }
}

struct SearchResponse: Codable {
    let offers: [FlightOffer]
    let currency: String
    let searchTimestamp: Date

    enum CodingKeys: String, CodingKey {
        case offers
        case currency
        case searchTimestamp = "search_timestamp"
    }
}
