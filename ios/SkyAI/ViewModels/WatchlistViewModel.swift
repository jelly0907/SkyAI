import Foundation
import Combine

/// ViewModel for the Watchlist tab.
///
/// Phase 1 (pre-backend) persisted watches to UserDefaults with hardcoded
/// sample data. Phase 2 swaps that for the real `/watch` API:
///
///   • `refresh()`           — GET /watch?user_id=demo-user
///   • `createWatch(...)`    — POST /watch
///   • `checkNow(id:)`       — POST /watch/{id}/check
///   • `deleteWatch(id:)`    — DELETE /watch/{id}
///
/// Auth lands in Phase 3; until then everyone is `demo-user`. UI rendering
/// uses `WatchResponse` directly — no more conversion to a local model.
@MainActor
final class WatchlistViewModel: ObservableObject {

    // ── State ───────────────────────────────────────────────────────────────
    @Published var watches: [WatchResponse] = []
    @Published var pastAlerts: [WatchResponse] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    /// Set to a watch's id while a per-row action (check / delete) is mid-flight,
    /// so the UI can show a spinner / disable the button on that one row only.
    @Published var rowInFlight: String?

    /// Last `WatchCheckResponse.reason` from a manual "Check now" — surfaced
    /// briefly in the UI so the user sees why a watch did or didn't trigger.
    @Published var lastCheckMessage: String?

    private let userId: String

    init(userId: String = "demo-user") {
        self.userId = userId
        Task { await refresh() }
    }

    // ── Reads ───────────────────────────────────────────────────────────────

    /// Refresh the watchlist from the backend. Splits triggered/inactive
    /// rows into `pastAlerts` so the existing two-section UI keeps working.
    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            let all = try await APIClient.shared.listWatches(userId: userId)
            // Active and not-yet-triggered rows live in the main section.
            // Anything triggered or explicitly deactivated drops into
            // "Past Alerts".
            self.watches    = all.filter { $0.active && $0.triggeredAt == nil }
            self.pastAlerts = all.filter { !$0.active || $0.triggeredAt != nil }
        } catch let err as SkyAIError {
            self.errorMessage = err.errorDescription
        } catch {
            self.errorMessage = "Couldn't load your watchlist."
        }
        isLoading = false
    }

    // ── Writes ──────────────────────────────────────────────────────────────

    /// Create a watch from a `FlightOffer` the user is currently viewing.
    /// Origin/destination come from the outbound itinerary; dates and cabin
    /// from the search request that produced the offer; the offer's current
    /// price becomes the default `target_price_usd`.
    func createWatch(
        from offer: FlightOffer,
        searchRequest: SearchRequest,
        targetPriceUsd: Double? = nil,
        notifyOnGreatDeal: Bool = true
    ) async {
        let outbound = offer.outbound
        guard let firstSegment = outbound.segments.first,
              let lastSegment  = outbound.segments.last
        else {
            errorMessage = "This offer is missing flight info — can't watch it."
            return
        }
        let request = WatchCreateRequest(
            userId: userId,
            origin: firstSegment.origin,
            destination: lastSegment.destination,
            departureDate: searchRequest.departureDate,
            returnDate: searchRequest.returnDate,
            cabinClass: searchRequest.cabinClass,
            adults: searchRequest.adults,
            maxStops: nil,
            targetPriceUsd: targetPriceUsd ?? offer.priceBreakdown.totalUsd,
            notifyOnGreatDeal: notifyOnGreatDeal
        )

        do {
            let watch = try await APIClient.shared.createWatch(request)
            // Optimistic insert at the top so the user immediately sees
            // their new watch.
            self.watches.insert(watch, at: 0)
        } catch let err as SkyAIError {
            self.errorMessage = err.errorDescription
        } catch {
            self.errorMessage = "Couldn't create the watch."
        }
    }

    /// Manually trigger a price check on a specific watch.
    func checkNow(id: String) async {
        rowInFlight = id
        defer { rowInFlight = nil }
        do {
            let result = try await APIClient.shared.checkWatch(id: id)
            // Replace the row with the freshly-checked watch so last_price /
            // last_label / triggered_at are up to date in the UI.
            replace(result.watch)
            self.lastCheckMessage = result.reason
        } catch let err as SkyAIError {
            self.errorMessage = err.errorDescription
        } catch {
            self.errorMessage = "Couldn't run the price check."
        }
    }

    func deleteWatch(id: String) async {
        rowInFlight = id
        defer { rowInFlight = nil }
        do {
            try await APIClient.shared.deleteWatch(id: id)
            self.watches.removeAll    { $0.id == id }
            self.pastAlerts.removeAll { $0.id == id }
        } catch let err as SkyAIError {
            self.errorMessage = err.errorDescription
        } catch {
            self.errorMessage = "Couldn't cancel the watch."
        }
    }

    // ── Internal helpers ────────────────────────────────────────────────────

    private func replace(_ watch: WatchResponse) {
        if let i = watches.firstIndex(where: { $0.id == watch.id }) {
            // Watch may have transitioned to past alerts (triggered).
            if !watch.active || watch.triggeredAt != nil {
                watches.remove(at: i)
                pastAlerts.insert(watch, at: 0)
            } else {
                watches[i] = watch
            }
        } else if let i = pastAlerts.firstIndex(where: { $0.id == watch.id }) {
            pastAlerts[i] = watch
        }
    }
}
