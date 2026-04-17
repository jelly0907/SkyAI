import Foundation
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    @Published var naturalQuery: String = ""
    @Published var searchRequest: SearchRequest = SearchRequest()
    @Published var interpretation: String = ""
    @Published var isParsingIntent: Bool = false
    @Published var intentError: String? = nil
    @Published var showStructuredForm: Bool = false
    @Published var shouldNavigateToResults: Bool = false

    private var apiClient = APIClient.shared

    // MARK: - Validation

    func isQueryValid() -> Bool {
        !naturalQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func isStructuredFormValid() -> Bool {
        !searchRequest.originCode.isEmpty &&
        !searchRequest.destinationCode.isEmpty &&
        searchRequest.adults > 0
    }

    // MARK: - Intent Parsing

    func parseIntent() async {
        guard isQueryValid() else {
            intentError = "Please enter a search query"
            return
        }

        isParsingIntent = true
        intentError = nil

        do {
            let response = try await apiClient.parseIntent(query: naturalQuery)
            self.searchRequest = response.searchRequest
            self.interpretation = response.interpretation
            self.shouldNavigateToResults = true
        } catch {
            intentError = error.localizedDescription
        }

        isParsingIntent = false
    }

    // MARK: - Search

    func search() async {
        if !naturalQuery.isEmpty {
            await parseIntent()
        } else if isStructuredFormValid() {
            shouldNavigateToResults = true
        } else {
            intentError = "Please enter an origin and destination"
        }
    }

    // MARK: - Form Helpers

    func setDefaultReturnDate() {
        if searchRequest.tripType == .oneWay {
            searchRequest.returnDate = nil
        } else if searchRequest.returnDate == nil || searchRequest.returnDate! <= searchRequest.departureDate {
            searchRequest.returnDate = Calendar.current.date(byAdding: .day, value: 30, to: searchRequest.departureDate)
        }
    }

    func resetForm() {
        naturalQuery = ""
        searchRequest = SearchRequest()
        interpretation = ""
        intentError = nil
        showStructuredForm = false
        shouldNavigateToResults = false
    }
}
