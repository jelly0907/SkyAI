import Foundation

enum WatchStatus: String, Codable {
    case active    = "ACTIVE"
    case triggered = "TRIGGERED"
    case expired   = "EXPIRED"
    case paused    = "PAUSED"
}

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
