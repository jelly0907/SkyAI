import SwiftUI
import Combine

struct ProfileView: View {
    @EnvironmentObject private var profileStore: UserProfileStore
    @State private var showResetAlert = false
    @State private var showEditProfile = false

    private let primaryColor = Color(red: 0.1, green: 0.235, blue: 0.42)
    private let accentColor  = Color(red: 1.0, green: 0.42, blue: 0.21)

    private var profile: UserProfile { profileStore.profile }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Avatar + Name ──────────────────────────────────────
                    avatarHeader

                    // ── Traveler Label Card ────────────────────────────────
                    travelerLabelCard

                    // ── Personal Info ──────────────────────────────────────
                    infoSection

                    // ── Travel Style ───────────────────────────────────────
                    travelStyleSection

                    // ── Memberships ────────────────────────────────────────
                    membershipsSection

                    // ── Privacy & Data ─────────────────────────────────────
                    privacySection

                    Text("SkyAI v1.0.0")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.systemGray4))
                        .padding(.bottom, 20)
                }
                .padding(.top, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") { showEditProfile = true }
                        .tint(accentColor)
                }
            }
            .sheet(isPresented: $showEditProfile) {
                OnboardingContainerView()
                    .environmentObject(profileStore)
            }
            .alert("Reset Personalization", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) {
                    profileStore.profile = UserProfile()
                    profileStore.isOnboardingComplete = false
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will erase all your preferences and travel history. You'll go through onboarding again.")
            }
        }
    }

    // MARK: - Avatar Header

    private var avatarHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [primaryColor, primaryColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 88, height: 88)

                Text(initials)
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.white)
            }

            VStack(spacing: 4) {
                Text(profile.firstName.isEmpty ? "Traveler" : "\(profile.firstName) \(profile.lastName)")
                    .font(.system(size: 22, weight: .bold))

                Text(profile.jobCategory.displayName)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                if !profile.countryOfResidence.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(accentColor)
                        Text(profile.countryOfResidence)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Traveler Label Card

    private var travelerLabelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "person.text.rectangle.fill")
                    .foregroundColor(accentColor)
                Text("Your Traveler Profile")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }

            // Primary label
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(primaryColor)
                        .frame(width: 48, height: 48)
                    Image(systemName: travelerTypeIcon)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(travelerTypeLabel)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                    Text(travelerTypeDescription)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            // Label dimensions grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                LabelDimensionCell(
                    title: "Budget",
                    value: profile.budgetSensitivity.displayName,
                    icon: "creditcard.fill",
                    color: primaryColor
                )
                LabelDimensionCell(
                    title: "Style",
                    value: profile.directFlightsPreferred ? "Direct Preferred" : "Flexible",
                    icon: "slider.horizontal.3",
                    color: .blue
                )
                LabelDimensionCell(
                    title: "Loyalty",
                    value: profile.loyaltyPrograms.isEmpty ? "No Programs" : "\(profile.loyaltyPrograms.count) Program(s)",
                    icon: "star.fill",
                    color: .orange
                )
                LabelDimensionCell(
                    title: "Age Group",
                    value: profile.ageBucket.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                    icon: "person.fill",
                    color: .green
                )
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .padding(.horizontal, 20)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        ProfileSectionCard(title: "Personal Info", icon: "person.circle.fill") {
            ProfileRow(label: "Name", value: profile.firstName.isEmpty ? "Not set" : "\(profile.firstName) \(profile.lastName)")
            Divider().padding(.leading, 16)
            ProfileRow(label: "Age Group", value: profile.ageBucket.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
            Divider().padding(.leading, 16)
            ProfileRow(label: "Occupation", value: profile.jobCategory.displayName)
            Divider().padding(.leading, 16)
            ProfileRow(label: "Work Travel", value: profile.isFrequentBusinessTraveler ? "Frequent" : "Occasional")
        }
    }

    // MARK: - Travel Style Section

    private var travelStyleSection: some View {
        ProfileSectionCard(title: "Travel Style", icon: "airplane.circle.fill") {
            ProfileRow(label: "Priority", value: profile.budgetSensitivity.displayName)
            Divider().padding(.leading, 16)
            ProfileRow(
                label: "Departure",
                value: profile.preferredDepartureWindows.isEmpty
                    ? "Any time"
                    : profile.preferredDepartureWindows.map(\.displayName).joined(separator: ", ")
            )
            Divider().padding(.leading, 16)
            ProfileRow(
                label: "Max Layover",
                value: profile.maxLayoverHours == 0 ? "Direct only" : "\(profile.maxLayoverHours)h"
            )
            Divider().padding(.leading, 16)
            ProfileRow(label: "Direct Preferred", value: profile.directFlightsPreferred ? "Yes" : "No")
        }
    }

    // MARK: - Memberships Section

    private var membershipsSection: some View {
        ProfileSectionCard(title: "Airline Memberships", icon: "star.circle.fill") {
            if profile.loyaltyPrograms.isEmpty {
                Text("No programs added")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(profile.loyaltyPrograms.enumerated()), id: \.element.id) { index, program in
                    if index > 0 { Divider().padding(.leading, 16) }
                    HStack(spacing: 12) {
                        Text(program.airlineCode)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 28)
                            .background(primaryColor)
                            .cornerRadius(6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(program.programName)
                                .font(.system(size: 14, weight: .semibold))
                            Text(program.tier.displayName)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            if profile.alliancePreference != .none {
                Divider().padding(.leading, 16)
                ProfileRow(label: "Alliance", value: profile.alliancePreference.displayName)
            }
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        ProfileSectionCard(title: "Privacy & Data", icon: "lock.circle.fill") {
            HStack {
                Image(systemName: "iphone")
                    .foregroundColor(.green)
                    .frame(width: 24)
                Text("Data stored on-device only")
                    .font(.system(size: 15))
                Spacer()
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.leading, 16)

            Button(action: { showResetAlert = true }) {
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    Text("Reset all personalization")
                        .font(.system(size: 15))
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Computed Helpers

    private var initials: String {
        let f = profile.firstName.first.map(String.init) ?? ""
        let l = profile.lastName.first.map(String.init) ?? ""
        return (f + l).isEmpty ? "?" : (f + l)
    }

    private var travelerTypeLabel: String {
        switch (profile.jobCategory, profile.budgetSensitivity, profile.isFrequentBusinessTraveler) {
        case (.student, _, _):                          return "Student Traveler"
        case (_, _, true) where profile.budgetSensitivity == .luxury: return "Business Road Warrior"
        case (_, _, true):                              return "Corporate Traveler"
        case (_, .priceFirst, _):                       return "Budget Explorer"
        case (_, .luxury, _):                           return "Luxury Traveler"
        case (.retired, _, _):                          return "Senior Traveler"
        case (_, .comfortFirst, _):                     return "Comfort Seeker"
        default:                                        return "Balanced Traveler"
        }
    }

    private var travelerTypeIcon: String {
        switch profile.budgetSensitivity {
        case .priceFirst:   return "backpack.fill"
        case .balanced:     return "figure.walk"
        case .comfortFirst: return "sofa.fill"
        case .luxury:       return "crown.fill"
        }
    }

    private var travelerTypeDescription: String {
        switch profile.budgetSensitivity {
        case .priceFirst:   return "Always finds the best deal, flexible with routes and times."
        case .balanced:     return "Values a good price without sacrificing too much comfort."
        case .comfortFirst: return "Prioritizes direct flights and a comfortable journey."
        case .luxury:       return "Travels in style — business or first class preferred."
        }
    }
}

// MARK: - Supporting Views

struct ProfileSectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    private let accentColor = Color(red: 1.0, green: 0.42, blue: 0.21)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
        }
        .padding(.horizontal, 20)
    }
}

struct ProfileRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct LabelDimensionCell: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(10)
    }
}

#Preview {
    ProfileView()
        .environmentObject(UserProfileStore.shared)
}
