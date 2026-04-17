import SwiftUI

/// Step 2 — Travel Style
/// Collects: budget attitude, preferred departure windows,
/// max layover tolerance, direct flight preference, special assistance.
struct OnboardingStep2View: View {
    @Binding var profile: UserProfile

    private let accentColor = Color(red: 1.0, green: 0.42, blue: 0.21)
    private let primaryColor = Color(red: 0.1, green: 0.235, blue: 0.42)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // ── Header ─────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your travel style")
                        .font(.system(size: 28, weight: .bold))

                    Text("We'll rank flights the way YOU want — not just by price.")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // ── Budget Attitude ────────────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(icon: "creditcard.fill", title: "What matters most to you?")

                    VStack(spacing: 10) {
                        ForEach(BudgetSensitivity.allCases, id: \.self) { option in
                            BudgetOptionRow(
                                option: option,
                                isSelected: profile.budgetSensitivity == option,
                                accentColor: accentColor
                            ) {
                                profile.budgetSensitivity = option
                            }
                        }
                    }
                }

                // ── Preferred Departure Windows ────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(icon: "clock.fill", title: "Preferred departure times")
                    Text("Select all that apply")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(DepartureWindow.allCases, id: \.self) { window in
                            let isSelected = profile.preferredDepartureWindows.contains(window)
                            Button(action: {
                                if isSelected {
                                    profile.preferredDepartureWindows.removeAll { $0 == window }
                                } else {
                                    profile.preferredDepartureWindows.append(window)
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Text(window.displayName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(isSelected ? .white : .primary)
                                    Text(window.timeRange)
                                        .font(.system(size: 11))
                                        .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(isSelected ? accentColor : Color(.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                                .animation(.easeInOut(duration: 0.15), value: isSelected)
                            }
                        }
                    }
                }

                // ── Layover Tolerance ──────────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(icon: "airplane.arrival", title: "Maximum layover time")

                    VStack(spacing: 8) {
                        HStack {
                            Text(profile.maxLayoverHours == 0 ? "Direct flights only" : "\(profile.maxLayoverHours) hour\(profile.maxLayoverHours == 1 ? "" : "s") max")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(primaryColor)
                            Spacer()
                        }

                        Slider(
                            value: Binding(
                                get: { Double(profile.maxLayoverHours) },
                                set: { profile.maxLayoverHours = Int($0) }
                            ),
                            in: 0...12,
                            step: 1
                        )
                        .tint(accentColor)

                        HStack {
                            Text("Direct only")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("12 hours")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }

                // ── Toggles ────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(icon: "slider.horizontal.3", title: "Other preferences")

                    VStack(spacing: 0) {
                        PreferenceToggleRow(
                            icon: "arrow.up.right",
                            title: "Prefer direct flights",
                            subtitle: "Show direct options first when available",
                            isOn: $profile.directFlightsPreferred,
                            accentColor: accentColor
                        )

                        Divider().padding(.leading, 48)

                        PreferenceToggleRow(
                            icon: "figure.roll",
                            title: "Special assistance needed",
                            subtitle: "Accessibility support, medical equipment",
                            isOn: $profile.specialAssistanceNeeded,
                            accentColor: accentColor
                        )
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }

                Spacer(minLength: 20)
            }
            .padding(24)
        }
    }
}

// MARK: - Supporting Views

struct BudgetOptionRow: View {
    let option: BudgetSensitivity
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(option.icon)
                    .font(.system(size: 24))

                VStack(alignment: .leading, spacing: 3) {
                    Text(option.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(option.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? accentColor : Color(uiColor: .systemGray4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? accentColor.opacity(0.08) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? accentColor : Color.clear, lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
    }
}

struct PreferenceToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let accentColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(accentColor)
        }
        .padding(14)
    }
}

#Preview {
    OnboardingStep2View(profile: .constant(UserProfile()))
}
