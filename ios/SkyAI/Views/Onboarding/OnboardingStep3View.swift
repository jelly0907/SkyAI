import SwiftUI

/// Step 3 — Airline Memberships
/// Collects: loyalty programs (program name + tier), alliance preference.
/// Contains the final "Get Started" CTA that triggers onboarding completion.
struct OnboardingStep3View: View {
    @Binding var profile: UserProfile
    let onComplete: () -> Void

    @State private var showAddProgram = false
    @State private var newProgramName = ""
    @State private var newAirlineCode = ""
    @State private var newTier: LoyaltyTier = .basic

    private let accentColor  = Color(red: 1.0, green: 0.42, blue: 0.21)
    private let primaryColor = Color(red: 0.1, green: 0.235, blue: 0.42)

    // Popular loyalty programs for quick-add
    private let popularPrograms: [(name: String, code: String)] = [
        ("ANA Mileage Club", "NH"),
        ("United MileagePlus", "UA"),
        ("Delta SkyMiles", "DL"),
        ("American AAdvantage", "AA"),
        ("Japan Airlines Mileage Bank", "JL"),
        ("Singapore KrisFlyer", "SQ"),
        ("Cathay Pacific Asia Miles", "CX"),
        ("Emirates Skywards", "EK"),
        ("Lufthansa Miles & More", "LH"),
        ("British Airways Avios", "BA"),
        ("Korean Air SKYPASS", "KE"),
        ("Qatar Privilege Club", "QR"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // ── Header ─────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your memberships")
                        .font(.system(size: 28, weight: .bold))

                    Text("We'll prioritize flights that earn miles on your existing programs.")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // ── Added Programs ─────────────────────────────────────────
                if !profile.loyaltyPrograms.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(icon: "star.fill", title: "Your programs")

                        VStack(spacing: 8) {
                            ForEach(profile.loyaltyPrograms) { program in
                                AddedProgramRow(program: program, accentColor: accentColor) {
                                    profile.loyaltyPrograms.removeAll { $0.id == program.id }
                                }
                            }
                        }
                    }
                }

                // ── Quick Add ──────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(icon: "plus.circle.fill", title: "Add a loyalty program")

                    // Popular programs grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(popularPrograms, id: \.code) { program in
                            let alreadyAdded = profile.loyaltyPrograms.contains { $0.airlineCode == program.code }

                            Button(action: {
                                if !alreadyAdded {
                                    profile.loyaltyPrograms.append(
                                        LoyaltyProgram(
                                            programName: program.name,
                                            airlineCode: program.code,
                                            tier: .basic
                                        )
                                    )
                                }
                            }) {
                                HStack(spacing: 8) {
                                    // Airline code badge
                                    Text(program.code)
                                        .font(.system(size: 12, weight: .black, design: .monospaced))
                                        .foregroundColor(.white)
                                        .frame(width: 34, height: 28)
                                        .background(alreadyAdded ? Color.green : primaryColor)
                                        .cornerRadius(6)

                                    Text(program.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(alreadyAdded ? .secondary : .primary)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()

                                    Image(systemName: alreadyAdded ? "checkmark" : "plus")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(alreadyAdded ? .green : accentColor)
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(alreadyAdded ? Color.green.opacity(0.08) : Color(.secondarySystemGroupedBackground))
                                )
                            }
                            .disabled(alreadyAdded)
                            .animation(.easeInOut(duration: 0.15), value: alreadyAdded)
                        }
                    }

                    // Custom program button
                    Button(action: { showAddProgram = true }) {
                        HStack {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(accentColor)
                            Text("Add a different program")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(accentColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(accentColor.opacity(0.08))
                        .cornerRadius(12)
                    }
                }

                // ── Alliance Preference ────────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(icon: "globe.asia.australia.fill", title: "Preferred alliance")

                    HStack(spacing: 8) {
                        ForEach(AlliancePreference.allCases, id: \.self) { alliance in
                            let isSelected = profile.alliancePreference == alliance
                            Button(action: { profile.alliancePreference = alliance }) {
                                Text(alliance.displayName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(isSelected ? primaryColor : Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(10)
                                    .animation(.easeInOut(duration: 0.15), value: isSelected)
                            }
                        }
                    }
                }

                // ── Skip note ─────────────────────────────────────────────
                Text("No memberships yet? No problem — you can add them later in your profile.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                // ── Get Started CTA ────────────────────────────────────────
                Button(action: onComplete) {
                    HStack(spacing: 10) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Let's find great flights!")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: accentColor.opacity(0.4), radius: 8, y: 4)
                }

                Spacer(minLength: 20)
            }
            .padding(24)
        }
        // ── Custom Program Sheet ───────────────────────────────────────────
        .sheet(isPresented: $showAddProgram) {
            AddCustomProgramSheet(
                programName: $newProgramName,
                airlineCode: $newAirlineCode,
                tier: $newTier,
                accentColor: accentColor
            ) {
                if !newProgramName.isEmpty {
                    profile.loyaltyPrograms.append(
                        LoyaltyProgram(
                            programName: newProgramName,
                            airlineCode: newAirlineCode.uppercased(),
                            tier: newTier
                        )
                    )
                    newProgramName = ""
                    newAirlineCode = ""
                    newTier = .basic
                }
                showAddProgram = false
            }
        }
    }
}

// MARK: - Supporting Views

struct AddedProgramRow: View {
    let program: LoyaltyProgram
    let accentColor: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(program.airlineCode)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 40, height: 32)
                .background(Color(red: 0.1, green: 0.235, blue: 0.42))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(program.programName)
                    .font(.system(size: 14, weight: .semibold))
                Text(program.tier.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(uiColor: .systemGray4))
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct AddCustomProgramSheet: View {
    @Binding var programName: String
    @Binding var airlineCode: String
    @Binding var tier: LoyaltyTier
    let accentColor: Color
    let onAdd: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Program details") {
                    TextField("Program name (e.g. ANA Mileage Club)", text: $programName)
                    TextField("Airline code (e.g. NH)", text: $airlineCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                Section("Your tier") {
                    Picker("Tier", selection: $tier) {
                        ForEach(LoyaltyTier.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Add Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onAdd() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { onAdd() }
                        .disabled(programName.isEmpty)
                        .tint(accentColor)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    OnboardingStep3View(profile: .constant(UserProfile()), onComplete: {})
}
