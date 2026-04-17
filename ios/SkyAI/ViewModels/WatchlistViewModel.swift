import Foundation
import Combine

@MainActor
class WatchlistViewModel: ObservableObject {
    @Published var watches: [PriceWatch] = []
    @Published var pastAlerts: [PriceWatch] = []

    private let key = "skyai_watchlist"

    init() { load() }

    // MARK: - CRUD

    func addWatch(_ watch: PriceWatch) {
        watches.insert(watch, at: 0)
        save()
    }

    func removeWatch(id: UUID) {
        watches.removeAll { $0.id == id }
        save()
    }

    func togglePause(id: UUID) {
        if let i = watches.firstIndex(where: { $0.id == id }) {
            watches[i].status = watches[i].status == .paused ? .active : .paused
            save()
        }
    }

    func updateThreshold(id: UUID, newThreshold: Double) {
        if let i = watches.firstIndex(where: { $0.id == id }) {
            watches[i].alertThreshold = newThreshold
            save()
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(watches) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        // Load saved watches
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([PriceWatch].self, from: data) {
            watches = saved
        } else {
            // Seed with example watches for first-time users
            watches = Self.exampleWatches()
        }

        // Separate triggered/expired into past alerts
        pastAlerts = watches.filter { $0.status == .triggered || $0.status == .expired }
        watches = watches.filter { $0.status == .active || $0.status == .paused }
    }

    // MARK: - Sample Data

    static func exampleWatches() -> [PriceWatch] {
        let now = Date()
        return [
            PriceWatch(
                origin: "SFO", destination: "NRT",
                originCity: "San Francisco", destinationCity: "Tokyo",
                departureRange: "Jul 2026",
                currentBestPrice: 842, alertThreshold: 800,
                predictedLow: 788,
                predictedLowDate: Calendar.current.date(byAdding: .day, value: 4, to: now),
                priceLabel: .greatDeal, trend: .rising,
                status: .active,
                createdAt: Calendar.current.date(byAdding: .day, value: -3, to: now) ?? now,
                lastCheckedAt: now, triggeredAt: nil, airline: "NH",
                priceAtCreation: 1020
            ),
            PriceWatch(
                origin: "SFO", destination: "LHR",
                originCity: "San Francisco", destinationCity: "London",
                departureRange: "Aug 5–15",
                currentBestPrice: 1120, alertThreshold: 950,
                predictedLow: 910,
                predictedLowDate: Calendar.current.date(byAdding: .day, value: 12, to: now),
                priceLabel: .fair, trend: .falling,
                status: .active,
                createdAt: Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now,
                lastCheckedAt: now, triggeredAt: nil, airline: "BA",
                priceAtCreation: 1200
            ),
        ]
    }
}
