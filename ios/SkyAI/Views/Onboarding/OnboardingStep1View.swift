import SwiftUI

/// Step 1 — Personal Profile
/// Collects: name, date of birth, country of residence, job category,
/// and whether the user travels for work frequently.
struct OnboardingStep1View: View {
    @Binding var profile: UserProfile

    private let primaryColor = Color(red: 0.1, green: 0.235, blue: 0.42)
    private let accentColor  = Color(red: 1.0, green: 0.42, blue: 0.21)

    // Country list (abbreviated — full list via Locale in production)
    private let countries: [String] = Locale.isoRegionCodes
        .compactMap { Locale.current.localizedString(forRegionCode: $0) }
        .sorted()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // ── Header ─────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tell us about yourself")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)

                    Text("We use this to surface age-appropriate deals, student discounts, and senior fares.")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // ── Name ───────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(icon: "person.fill", title: "Your Name")

                    HStack(spacing: 12) {
                        OnboardingTextField(
                            placeholder: "First name",
                            text: $profile.firstName
                        )
                        OnboardingTextField(
                            placeholder: "Last name",
                            text: $profile.lastName
                        )
                    }
                }

                // ── Date of Birth ──────────────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(icon: "birthday.cake.fill", title: "Date of Birth")

                    HStack {
                        Text(profile.dateOfBirth.formatted(date: .long, time: .omitted))
                            .font(.system(size: 16))
                            .foregroundColor(.primary)

                        Spacer()

                        // Age bucket badge
                        Text(profile.ageBucket.rawValue.replacingOccurrences(of: "_", with: " "))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(accentColor)
                            .cornerRadius(20)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)

                    DatePicker(
                        "Date of Birth",
                        selection: $profile.dateOfBirth,
                        in: Calendar.current.date(byAdding: .year, value: -100, to: Date())!...Calendar.current.date(byAdding: .year, value: -5, to: Date())!,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }

                // ── Country ────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(icon: "globe", title: "Country of Residence")

                    Picker("Country", selection: $profile.countryOfResidence) {
                        Text("Select country").tag("")
                        ForEach(countries, id: \.self) { country in
                            Text(country).tag(country)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }

                // ── Job Category ───────────────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(icon: "briefcase.fill", title: "What do you do?")

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(JobCategory.allCases, id: \.self) { job in
                            JobCategoryCard(
                                job: job,
                                isSelected: profile.jobCategory == job,
                                accentColor: accentColor
                            ) {
                                profile.jobCategory = job
                            }
                        }
                    }
                }

                // ── Frequent Business Traveler ─────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(icon: "airplane", title: "Work Travel")

                    Toggle(isOn: $profile.isFrequentBusinessTraveler) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("I travel for work at least monthly")
                                .font(.system(size: 15, weight: .medium))
                            Text("We'll prioritize flexible fares and loyalty miles")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .tint(accentColor)
                }

                Spacer(minLength: 20)
            }
            .padding(24)
        }
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let icon: String
    let title: String
    private let primaryColor = Color(red: 0.1, green: 0.235, blue: 0.42)

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(primaryColor)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

struct OnboardingTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 16))
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
    }
}

struct JobCategoryCard: View {
    let job: JobCategory
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: job.icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .white : .primary)
                Text(job.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? accentColor : Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? accentColor : Color.clear, lineWidth: 2)
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
    }
}

#Preview {
    OnboardingStep1View(profile: .constant(UserProfile()))
}
