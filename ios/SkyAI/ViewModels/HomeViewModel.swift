import Foundation
import Combine

// MARK: - Feed Models

struct DealCard: Identifiable {
    let id = UUID()
    let origin: String
    let destination: String
    let destinationCity: String
    let price: Double
    let priceLabel: PriceLabel
    let badgeText: String
    let savingsPct: Int?
    let trend: PriceTrend
    let actionType: ActionType
    let departureDate: String
    let airline: String
    let durationText: String
    let stops: Int
}

struct RouteChip: Identifiable {
    let id = UUID()
    let destination: String
    let city: String
    let price: Double
    let priceLabel: PriceLabel
}

struct FeedSection: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let icon: String
    var dealCards: [DealCard] = []
    var routeChips: [RouteChip] = []
    let sectionType: SectionType

    enum SectionType {
        case dealCards       // vertical cards with full intel
        case horizontalChips // scrollable price chips
        case loyaltyRoutes   // airline-specific routes
    }
}

// MARK: - HomeViewModel

@MainActor
class HomeViewModel: ObservableObject {
    @Published var sections: [FeedSection] = []
    @Published var isLoading: Bool = true
    @Published var greetingText: String = "Good morning"
    @Published var userFirstName: String = ""

    private let store = UserProfileStore.shared
    private let apiClient = APIClient.shared

    // Home airport inferred from country of residence
    private var homeAirport: String {
        switch store.profile.countryOfResidence {
        case "United States", "US": return "SFO"
        case "Japan":               return "NRT"
        case "United Kingdom":      return "LHR"
        case "France":              return "CDG"
        case "Germany":             return "FRA"
        case "Singapore":           return "SIN"
        case "Australia":           return "SYD"
        case "South Korea":         return "ICN"
        case "China":               return "PEK"
        case "India":               return "DEL"
        default:                    return "SFO"
        }
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        userFirstName = store.profile.displayName
        greetingText = timeBasedGreeting()

        // Build personalized feed based on user label
        var newSections: [FeedSection] = []

        // Section 1 — personalized based on budget sensitivity
        newSections.append(buildPrimaryDealsSection())

        // Section 2 — cheapest from home airport (horizontal chips)
        newSections.append(buildCheapestFromHomeSection())

        // Section 3 — loyalty routes (if user has programs)
        if !store.profile.loyaltyPrograms.isEmpty {
            newSections.append(buildLoyaltySection())
        }

        // Section 4 — trending destinations
        newSections.append(buildTrendingSection())

        sections = newSections
        isLoading = false
    }

    func refresh() async {
        await load()
    }

    // MARK: - Section Builders

    private func buildPrimaryDealsSection() -> FeedSection {
        let profile = store.profile

        let title: String
        let subtitle: String
        let deals: [DealCard]

        switch profile.budgetSensitivity {
        case .priceFirst:
            title = "Cheapest flights right now"
            subtitle = "Best prices from \(homeAirport)"
            deals = budgetDeals(from: homeAirport)
        case .balanced:
            title = "Best value this week"
            subtitle = "Great prices + reasonable comfort"
            deals = balancedDeals(from: homeAirport)
        case .comfortFirst:
            title = "Premium picks for you"
            subtitle = "Direct flights with extra comfort"
            deals = comfortDeals(from: homeAirport)
        case .luxury:
            title = "Business class deals"
            subtitle = "Top-tier fares below average"
            deals = luxuryDeals(from: homeAirport)
        }

        return FeedSection(
            title: title,
            subtitle: subtitle,
            icon: "flame.fill",
            dealCards: deals,
            sectionType: .dealCards
        )
    }

    private func buildCheapestFromHomeSection() -> FeedSection {
        let chips: [RouteChip] = [
            RouteChip(destination: "NRT", city: "Tokyo",     price: 842,  priceLabel: .greatDeal),
            RouteChip(destination: "ICN", city: "Seoul",     price: 490,  priceLabel: .steal),
            RouteChip(destination: "LHR", city: "London",    price: 780,  priceLabel: .fair),
            RouteChip(destination: "CDG", city: "Paris",     price: 810,  priceLabel: .fair),
            RouteChip(destination: "SIN", city: "Singapore", price: 920,  priceLabel: .greatDeal),
            RouteChip(destination: "DPS", city: "Bali",      price: 389,  priceLabel: .steal),
            RouteChip(destination: "BKK", city: "Bangkok",   price: 520,  priceLabel: .greatDeal),
            RouteChip(destination: "DXB", city: "Dubai",     price: 1050, priceLabel: .fair),
        ]

        return FeedSection(
            title: "Cheapest from \(homeAirport)",
            subtitle: "This month's best prices",
            icon: "map.fill",
            routeChips: chips,
            sectionType: .horizontalChips
        )
    }

    private func buildLoyaltySection() -> FeedSection {
        let topProgram = store.profile.loyaltyPrograms.first!
        let airline = topProgram.airlineCode

        let routes = loyaltyRoutes(for: airline)

        return FeedSection(
            title: "\(topProgram.programName) routes",
            subtitle: "Earn miles on your \(topProgram.tier.displayName) status",
            icon: "star.fill",
            dealCards: routes,
            sectionType: .loyaltyRoutes
        )
    }

    private func buildTrendingSection() -> FeedSection {
        let deals: [DealCard] = [
            DealCard(
                origin: homeAirport, destination: "HKG",
                destinationCity: "Hong Kong",
                price: 680, priceLabel: .greatDeal,
                badgeText: "✅ GREAT DEAL",
                savingsPct: 22, trend: .falling,
                actionType: .wait,
                departureDate: "Jun 20–30",
                airline: "CX", durationText: "11h 20m", stops: 0
            ),
            DealCard(
                origin: homeAirport, destination: "SYD",
                destinationCity: "Sydney",
                price: 890, priceLabel: .fair,
                badgeText: "",
                savingsPct: nil, trend: .stable,
                actionType: .monitor,
                departureDate: "Aug 1–15",
                airline: "UA", durationText: "14h 50m", stops: 1
            ),
        ]

        return FeedSection(
            title: "Trending destinations",
            subtitle: "Popular routes this season",
            icon: "chart.line.uptrend.xyaxis",
            dealCards: deals,
            sectionType: .dealCards
        )
    }

    // MARK: - Mock Deal Generators

    private func budgetDeals(from origin: String) -> [DealCard] {[
        DealCard(
            origin: origin, destination: "ICN",
            destinationCity: "Seoul",
            price: 490, priceLabel: .steal,
            badgeText: "🔥 STEAL",
            savingsPct: 35, trend: .rising,
            actionType: .buyNow,
            departureDate: "May 15–22", airline: "KE",
            durationText: "9h 50m", stops: 0
        ),
        DealCard(
            origin: origin, destination: "DPS",
            destinationCity: "Bali",
            price: 389, priceLabel: .steal,
            badgeText: "🔥 STEAL",
            savingsPct: 41, trend: .rising,
            actionType: .buyNow,
            departureDate: "Jun 5–19", airline: "SQ",
            durationText: "17h 30m", stops: 1
        ),
        DealCard(
            origin: origin, destination: "BKK",
            destinationCity: "Bangkok",
            price: 520, priceLabel: .greatDeal,
            badgeText: "✅ GREAT DEAL",
            savingsPct: 28, trend: .stable,
            actionType: .buyNow,
            departureDate: "Jul 10–24", airline: "NH",
            durationText: "14h 20m", stops: 1
        ),
    ]}

    private func balancedDeals(from origin: String) -> [DealCard] {[
        DealCard(
            origin: origin, destination: "NRT",
            destinationCity: "Tokyo",
            price: 842, priceLabel: .greatDeal,
            badgeText: "✅ GREAT DEAL",
            savingsPct: 19, trend: .rising,
            actionType: .buyNow,
            departureDate: "Jul 15–25", airline: "NH",
            durationText: "9h 55m", stops: 0
        ),
        DealCard(
            origin: origin, destination: "SIN",
            destinationCity: "Singapore",
            price: 920, priceLabel: .greatDeal,
            badgeText: "✅ GREAT DEAL",
            savingsPct: 16, trend: .stable,
            actionType: .buyNow,
            departureDate: "Aug 3–13", airline: "SQ",
            durationText: "16h 45m", stops: 0
        ),
    ]}

    private func comfortDeals(from origin: String) -> [DealCard] {[
        DealCard(
            origin: origin, destination: "NRT",
            destinationCity: "Tokyo",
            price: 1240, priceLabel: .greatDeal,
            badgeText: "✅ GREAT DEAL",
            savingsPct: 14, trend: .rising,
            actionType: .buyNow,
            departureDate: "Jul 15–25", airline: "NH",
            durationText: "9h 55m", stops: 0
        ),
        DealCard(
            origin: origin, destination: "LHR",
            destinationCity: "London",
            price: 980, priceLabel: .fair,
            badgeText: "",
            savingsPct: nil, trend: .falling,
            actionType: .wait,
            departureDate: "Sep 1–10", airline: "BA",
            durationText: "9h 40m", stops: 0
        ),
    ]}

    private func luxuryDeals(from origin: String) -> [DealCard] {[
        DealCard(
            origin: origin, destination: "NRT",
            destinationCity: "Tokyo",
            price: 3200, priceLabel: .greatDeal,
            badgeText: "✅ GREAT DEAL",
            savingsPct: 18, trend: .rising,
            actionType: .buyNow,
            departureDate: "Jul 15–25", airline: "NH",
            durationText: "9h 55m", stops: 0
        ),
        DealCard(
            origin: origin, destination: "DXB",
            destinationCity: "Dubai",
            price: 4100, priceLabel: .fair,
            badgeText: "",
            savingsPct: nil, trend: .stable,
            actionType: .monitor,
            departureDate: "Aug 10–20", airline: "EK",
            durationText: "15h 50m", stops: 0
        ),
    ]}

    private func loyaltyRoutes(for airlineCode: String) -> [DealCard] {
        let dest: (String, String, Double, String)
        switch airlineCode {
        case "NH": dest = ("NRT", "Tokyo",     842,  "NH")
        case "JL": dest = ("NRT", "Tokyo",     909,  "JL")
        case "UA": dest = ("LHR", "London",    780,  "UA")
        case "DL": dest = ("CDG", "Paris",     810,  "DL")
        case "AA": dest = ("LHR", "London",    760,  "AA")
        case "SQ": dest = ("SIN", "Singapore", 920,  "SQ")
        case "CX": dest = ("HKG", "Hong Kong", 680,  "CX")
        case "EK": dest = ("DXB", "Dubai",     1050, "EK")
        default:   dest = ("NRT", "Tokyo",     842,  airlineCode)
        }

        return [DealCard(
            origin: homeAirport, destination: dest.0,
            destinationCity: dest.1,
            price: dest.2, priceLabel: .greatDeal,
            badgeText: "✅ GREAT DEAL",
            savingsPct: 17, trend: .stable,
            actionType: .buyNow,
            departureDate: "Jul 15–25",
            airline: dest.3,
            durationText: "10h 0m", stops: 0
        )]
    }

    // MARK: - Helpers

    private func timeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Good night"
        }
    }
}
