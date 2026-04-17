import Foundation
import Combine

enum SortOption: String, CaseIterable {
    case price
    case duration
    case bestDeal

    var displayName: String {
        switch self {
        case .price:
            return "Price"
        case .duration:
            return "Duration"
        case .bestDeal:
            return "Best Deal"
        }
    }
}

@MainActor
class ResultsViewModel: ObservableObject {
    @Published var offers: [FlightOffer] = []
    @Published var isLoading: Bool = true
    @Published var errorMessage: String? = nil
    @Published var sortOption: SortOption = .price

    private var apiClient = APIClient.shared
    private var allOffers: [FlightOffer] = []

    var sortedOffers: [FlightOffer] {
        switch sortOption {
        case .price:
            return allOffers.sorted { $0.price < $1.price }
        case .duration:
            return allOffers.sorted { $0.outbound.durationMinutes < $1.outbound.durationMinutes }
        case .bestDeal:
            return allOffers.sorted { offer1, offer2 in
                let rank1 = offer1.priceIntelligence.percentileRank
                let rank2 = offer2.priceIntelligence.percentileRank
                return rank1 > rank2
            }
        }
    }

    func load(request: SearchRequest) async {
        isLoading = true
        errorMessage = nil
        offers = []
        allOffers = []

        do {
            let response = try await apiClient.searchFlights(request)
            self.allOffers = response.offers
            self.offers = sortedOffers
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func sort(by option: SortOption) {
        sortOption = option
        offers = sortedOffers
    }

    func retry(request: SearchRequest) async {
        await load(request: request)
    }
}
