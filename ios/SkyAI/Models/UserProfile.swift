import Foundation
import Combine

// MARK: - Enums

enum AgeBucket: String, Codable, CaseIterable {
    case child         = "CHILD"
    case teenager      = "TEENAGER"
    case youngAdult    = "YOUNG_ADULT"
    case youngPro      = "YOUNG_PROFESSIONAL"
    case midPro        = "MID_PROFESSIONAL"
    case preSenior     = "PRE_SENIOR"
    case senior        = "SENIOR"

    static func from(dateOfBirth: Date) -> AgeBucket {
        let age = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
        switch age {
        case ..<12:  return .child
        case 12..<18: return .teenager
        case 18..<26: return .youngAdult
        case 26..<36: return .youngPro
        case 36..<51: return .midPro
        case 51..<65: return .preSenior
        default:     return .senior
        }
    }
}

enum JobCategory: String, Codable, CaseIterable {
    case student           = "STUDENT"
    case professionalOffice = "PROFESSIONAL_OFFICE"
    case professionalMobile = "PROFESSIONAL_MOBILE"
    case selfEmployed      = "SELF_EMPLOYED"
    case healthcareWorker  = "HEALTHCARE_WORKER"
    case military          = "MILITARY"
    case retired           = "RETIRED"
    case other             = "OTHER"

    var displayName: String {
        switch self {
        case .student:            return "Student"
        case .professionalOffice: return "Office Professional"
        case .professionalMobile: return "Mobile Professional"
        case .selfEmployed:       return "Self-Employed"
        case .healthcareWorker:   return "Healthcare Worker"
        case .military:           return "Military"
        case .retired:            return "Retired"
        case .other:              return "Other"
        }
    }

    var icon: String {
        switch self {
        case .student:            return "graduationcap.fill"
        case .professionalOffice: return "building.2.fill"
        case .professionalMobile: return "briefcase.fill"
        case .selfEmployed:       return "person.crop.circle.fill"
        case .healthcareWorker:   return "cross.fill"
        case .military:           return "shield.fill"
        case .retired:            return "sun.horizon.fill"
        case .other:              return "ellipsis.circle.fill"
        }
    }
}

enum BudgetSensitivity: String, Codable, CaseIterable {
    case priceFirst    = "PRICE_FIRST"
    case balanced      = "BALANCED"
    case comfortFirst  = "COMFORT_FIRST"
    case luxury        = "LUXURY"

    var displayName: String {
        switch self {
        case .priceFirst:   return "Price First"
        case .balanced:     return "Balanced"
        case .comfortFirst: return "Comfort First"
        case .luxury:       return "Luxury"
        }
    }

    var icon: String {
        switch self {
        case .priceFirst:   return "💸"
        case .balanced:     return "⚖️"
        case .comfortFirst: return "🛋️"
        case .luxury:       return "✨"
        }
    }

    var description: String {
        switch self {
        case .priceFirst:   return "Always the cheapest option, even with long layovers"
        case .balanced:     return "Good value with reasonable comfort"
        case .comfortFirst: return "Willing to pay more for direct flights and comfort"
        case .luxury:       return "Business or first class preferred"
        }
    }
}

enum DepartureWindow: String, Codable, CaseIterable {
    case earlyMorning = "EARLY_MORNING"
    case morning      = "MORNING"
    case afternoon    = "AFTERNOON"
    case evening      = "EVENING"
    case redEye       = "RED_EYE"

    var displayName: String {
        switch self {
        case .earlyMorning: return "Early Morning"
        case .morning:      return "Morning"
        case .afternoon:    return "Afternoon"
        case .evening:      return "Evening"
        case .redEye:       return "Red-eye"
        }
    }

    var timeRange: String {
        switch self {
        case .earlyMorning: return "05:00–08:00"
        case .morning:      return "08:00–12:00"
        case .afternoon:    return "12:00–17:00"
        case .evening:      return "17:00–21:00"
        case .redEye:       return "21:00–05:00"
        }
    }
}

enum AlliancePreference: String, Codable, CaseIterable {
    case starAlliance = "STAR_ALLIANCE"
    case oneworld     = "ONEWORLD"
    case skyteam      = "SKYTEAM"
    case none         = "NO_PREFERENCE"

    var displayName: String {
        switch self {
        case .starAlliance: return "Star Alliance"
        case .oneworld:     return "Oneworld"
        case .skyteam:      return "SkyTeam"
        case .none:         return "No preference"
        }
    }
}

enum LoyaltyTier: String, Codable, CaseIterable {
    case basic    = "BASIC"
    case silver   = "SILVER"
    case gold     = "GOLD"
    case platinum = "PLATINUM"
    case diamond  = "DIAMOND"

    var displayName: String { rawValue.capitalized }
}

// MARK: - Sub-models

struct LoyaltyProgram: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var programName: String        // e.g. "ANA Mileage Club"
    var airlineCode: String        // e.g. "NH"
    var tier: LoyaltyTier
    var memberId: String = ""      // optional — kept on device only

    enum CodingKeys: String, CodingKey {
        case id, programName, airlineCode, tier, memberId
    }
}

// MARK: - Main UserProfile

struct UserProfile: Codable {
    // Step 1 — Personal
    var firstName: String = ""
    var lastName: String = ""
    var dateOfBirth: Date = Calendar.current.date(
        byAdding: .year, value: -28, to: Date()) ?? Date()
    var nationality: String = ""
    var countryOfResidence: String = ""
    var jobCategory: JobCategory = .professionalOffice
    var isFrequentBusinessTraveler: Bool = false

    // Step 2 — Travel Style
    var budgetSensitivity: BudgetSensitivity = .balanced
    var preferredDepartureWindows: [DepartureWindow] = [.morning, .afternoon]
    var maxLayoverHours: Int = 4
    var directFlightsPreferred: Bool = false
    var specialAssistanceNeeded: Bool = false

    // Step 3 — Memberships
    var loyaltyPrograms: [LoyaltyProgram] = []
    var alliancePreference: AlliancePreference = .none

    // Computed
    var ageBucket: AgeBucket {
        AgeBucket.from(dateOfBirth: dateOfBirth)
    }

    var displayName: String {
        firstName.isEmpty ? "Traveler" : firstName
    }
}

// MARK: - UserProfile Storage

class UserProfileStore: ObservableObject {
    static let shared = UserProfileStore()

    private let key = "skyai_user_profile"
    private let onboardingKey = "skyai_onboarding_complete"

    @Published var profile: UserProfile = UserProfile()
    @Published var isOnboardingComplete: Bool = false

    init() {
        load()
    }

    func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
        UserDefaults.standard.set(isOnboardingComplete, forKey: onboardingKey)
    }

    func completeOnboarding() {
        isOnboardingComplete = true
        save()
    }

    private func load() {
        isOnboardingComplete = UserDefaults.standard.bool(forKey: onboardingKey)
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = saved
        }
    }
}
