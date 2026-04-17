package com.skyai.app.data.model

import java.util.Date
import java.util.UUID

// ── Enums ────────────────────────────────────────────────────────────────────

enum class AgeBucket(val label: String) {
    CHILD("Child"),
    TEENAGER("Teenager"),
    YOUNG_ADULT("Young Adult"),
    YOUNG_PROFESSIONAL("Young Professional"),
    MID_PROFESSIONAL("Mid Professional"),
    PRE_SENIOR("Pre-Senior"),
    SENIOR("Senior");

    companion object {
        fun from(birthYear: Int): AgeBucket {
            val age = java.util.Calendar.getInstance().get(java.util.Calendar.YEAR) - birthYear
            return when {
                age < 12  -> CHILD
                age < 18  -> TEENAGER
                age < 26  -> YOUNG_ADULT
                age < 36  -> YOUNG_PROFESSIONAL
                age < 51  -> MID_PROFESSIONAL
                age < 65  -> PRE_SENIOR
                else      -> SENIOR
            }
        }
    }
}

enum class JobCategory(val displayName: String, val icon: String) {
    STUDENT("Student", "school"),
    PROFESSIONAL_OFFICE("Office Professional", "business"),
    PROFESSIONAL_MOBILE("Mobile Professional", "work"),
    SELF_EMPLOYED("Self-Employed", "person"),
    HEALTHCARE_WORKER("Healthcare Worker", "local_hospital"),
    MILITARY("Military", "shield"),
    RETIRED("Retired", "wb_sunny"),
    OTHER("Other", "more_horiz")
}

enum class BudgetSensitivity(val displayName: String, val emoji: String, val description: String) {
    PRICE_FIRST("Price First", "💸", "Always the cheapest, even with long layovers"),
    BALANCED("Balanced", "⚖️", "Good value with reasonable comfort"),
    COMFORT_FIRST("Comfort First", "🛋️", "Willing to pay more for direct flights"),
    LUXURY("Luxury", "✨", "Business or first class preferred")
}

enum class DepartureWindow(val displayName: String, val timeRange: String) {
    EARLY_MORNING("Early Morning", "05:00–08:00"),
    MORNING("Morning", "08:00–12:00"),
    AFTERNOON("Afternoon", "12:00–17:00"),
    EVENING("Evening", "17:00–21:00"),
    RED_EYE("Red-eye", "21:00–05:00")
}

enum class AlliancePreference(val displayName: String) {
    STAR_ALLIANCE("Star Alliance"),
    ONEWORLD("Oneworld"),
    SKYTEAM("SkyTeam"),
    NO_PREFERENCE("No preference")
}

enum class LoyaltyTier(val displayName: String) {
    BASIC("Basic"),
    SILVER("Silver"),
    GOLD("Gold"),
    PLATINUM("Platinum"),
    DIAMOND("Diamond")
}

// ── Sub-models ────────────────────────────────────────────────────────────────

data class LoyaltyProgram(
    val id: String = UUID.randomUUID().toString(),
    val programName: String,
    val airlineCode: String,
    val tier: LoyaltyTier = LoyaltyTier.BASIC,
    val memberId: String = ""
)

// ── Main UserProfile ──────────────────────────────────────────────────────────

data class UserProfile(
    // Step 1
    val firstName: String = "",
    val lastName: String = "",
    val birthYear: Int = 1996,
    val countryOfResidence: String = "",
    val jobCategory: JobCategory = JobCategory.PROFESSIONAL_OFFICE,
    val isFrequentBusinessTraveler: Boolean = false,

    // Step 2
    val budgetSensitivity: BudgetSensitivity = BudgetSensitivity.BALANCED,
    val preferredDepartureWindows: List<DepartureWindow> = listOf(DepartureWindow.MORNING),
    val maxLayoverHours: Int = 4,
    val directFlightsPreferred: Boolean = false,
    val specialAssistanceNeeded: Boolean = false,

    // Step 3
    val loyaltyPrograms: List<LoyaltyProgram> = emptyList(),
    val alliancePreference: AlliancePreference = AlliancePreference.NO_PREFERENCE,

    val isOnboardingComplete: Boolean = false
) {
    val displayName: String get() = firstName.ifEmpty { "Traveler" }
    val fullName: String get() = "$firstName $lastName".trim()
    val ageBucket: AgeBucket get() = AgeBucket.from(birthYear)

    val travelerTypeLabel: String get() = when {
        jobCategory == JobCategory.STUDENT                    -> "Student Traveler"
        isFrequentBusinessTraveler && budgetSensitivity == BudgetSensitivity.LUXURY -> "Business Road Warrior"
        isFrequentBusinessTraveler                            -> "Corporate Traveler"
        budgetSensitivity == BudgetSensitivity.PRICE_FIRST   -> "Budget Explorer"
        budgetSensitivity == BudgetSensitivity.LUXURY        -> "Luxury Traveler"
        jobCategory == JobCategory.RETIRED                   -> "Senior Traveler"
        budgetSensitivity == BudgetSensitivity.COMFORT_FIRST -> "Comfort Seeker"
        else                                                  -> "Balanced Traveler"
    }
}

// ── PriceWatch ────────────────────────────────────────────────────────────────

enum class WatchStatus { ACTIVE, PAUSED, TRIGGERED, EXPIRED }

data class PriceWatch(
    val id: String = UUID.randomUUID().toString(),
    val origin: String,
    val destination: String,
    val originCity: String,
    val destinationCity: String,
    val departureRange: String,
    val currentBestPrice: Double,
    val alertThreshold: Double,
    val predictedLow: Double? = null,
    val priceAtCreation: Double,
    val trend: PriceTrend = PriceTrend.STABLE,
    val status: WatchStatus = WatchStatus.ACTIVE,
    val airline: String? = null
) {
    val savings: Double get() = priceAtCreation - currentBestPrice
    val savingsPct: Int get() = ((savings / priceAtCreation) * 100).toInt()
}
