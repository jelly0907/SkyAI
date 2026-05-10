import Foundation

// MARK: - Backend wire models
//
// These mirror the Pydantic types in backend/models.py exactly:
//   - WatchCreateRequest  (request body for POST /watch)
//   - WatchResponse       (return shape of POST/GET /watch and /watch/{id})
//   - WatchCheckResponse  (return shape of POST /watch/{id}/check)
//
// Property names stay camelCase in Swift; CodingKeys handle the snake_case
// JSON mapping. Date fields are decoded by APIClient's date strategy
// (full ISO8601 for `created_at` / `last_checked_at` / `triggered_at`,
// plain "yyyy-MM-dd" for `departure_date` / `return_date`).

struct WatchCreateRequest: Codable {
    var userId: String
    var origin: String
    var destination: String
    var departureDate: Date
    var returnDate: Date?
    var cabinClass: CabinClass = .economy
    var adults: Int = 1
    var maxStops: Int?
    var targetPriceUsd: Double?
    var notifyOnGreatDeal: Bool = true

    enum CodingKeys: String, CodingKey {
        case userId               = "user_id"
        case origin
        case destination
        case departureDate        = "departure_date"
        case returnDate           = "return_date"
        case cabinClass           = "cabin_class"
        case adults
        case maxStops             = "max_stops"
        case targetPriceUsd       = "target_price_usd"
        case notifyOnGreatDeal    = "notify_on_great_deal"
    }
}

struct WatchResponse: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let origin: String
    let destination: String
    let departureDate: Date
    let returnDate: Date?
    let cabinClass: CabinClass
    let adults: Int
    let maxStops: Int?
    let targetPriceUsd: Double?
    let notifyOnGreatDeal: Bool
    let active: Bool
    let createdAt: Date
    let lastCheckedAt: Date?
    let lastPriceUsd: Double?
    let lastLabel: PriceLabel?
    let triggeredAt: Date?
    let triggerCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case userId            = "user_id"
        case origin
        case destination
        case departureDate     = "departure_date"
        case returnDate        = "return_date"
        case cabinClass        = "cabin_class"
        case adults
        case maxStops          = "max_stops"
        case targetPriceUsd    = "target_price_usd"
        case notifyOnGreatDeal = "notify_on_great_deal"
        case active
        case createdAt         = "created_at"
        case lastCheckedAt     = "last_checked_at"
        case lastPriceUsd      = "last_price_usd"
        case lastLabel         = "last_label"
        case triggeredAt       = "triggered_at"
        case triggerCount      = "trigger_count"
    }

    // Derived display state — the local UI used to track this in its own
    // enum, but the backend exposes only `active` + `triggered_at`. Map back
    // to the same four-state model the UI already handles.
    var derivedStatus: WatchStatus {
        if !active { return .paused }
        if triggeredAt != nil { return .triggered }
        return .active
    }
}

struct WatchCheckResponse: Codable {
    let watch: WatchResponse
    let triggered: Bool
    let bestPriceUsd: Double?
    let bestLabel: PriceLabel?
    let bestOffer: FlightOffer?
    let reason: String
    let checkedAt: Date

    enum CodingKeys: String, CodingKey {
        case watch
        case triggered
        case bestPriceUsd  = "best_price_usd"
        case bestLabel     = "best_label"
        case bestOffer     = "best_offer"
        case reason
        case checkedAt     = "checked_at"
    }
}

// MARK: - Local UI status enum
// Kept because the existing WatchlistView already renders these four cases.
// `WatchResponse.derivedStatus` maps the backend's `active` / `triggered_at`
// signals onto this enum.

enum WatchStatus: String, Codable {
    case active    = "ACTIVE"
    case triggered = "TRIGGERED"
    case expired   = "EXPIRED"
    case paused    = "PAUSED"
}

// MARK: - Legacy local-only model
//
// Pre-Phase-2 the watchlist persisted to UserDefaults using this rich
// "display ready" model. We're migrating the UI to render WatchResponse
// directly, but until that refactor is complete this struct stays so
// existing references in WatchlistView / WatchlistViewModel keep compiling.
// New code should use WatchResponse, not PriceWatch.

struct PriceWatch: Identifiable, Codable {
    var id: UUID = UUID()
    var origin: String
    var destination: String
    var originCity: String
    var destinationCity: String
    var departureRange: String          // e.g. "Jul 2026" or "Jul 10–20"
    var currentBestPrice: Double
    var alertThreshold: Double          // notify when price hits this
    var predictedLow: Double?
    var predictedLowDate: Date?
    var priceLabel: PriceLabel
    var trend: PriceTrend
    var status: WatchStatus
    var createdAt: Date
    var lastCheckedAt: Date
    var triggeredAt: Date?
    var airline: String?

    // How much the price has dropped since watch was created
    var priceAtCreation: Double

    var savings: Double { priceAtCreation - currentBestPrice }
    var savingsPct: Int { Int((savings / priceAtCreation) * 100) }
    var isTriggered: Bool { currentBestPrice <= alertThreshold }
}
