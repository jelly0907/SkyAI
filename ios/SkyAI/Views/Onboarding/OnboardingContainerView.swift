import SwiftUI
import Combine

/// Root container that drives the 3-step onboarding flow.
/// Holds the current step and shared profile state.
struct OnboardingContainerView: View {
    @StateObject private var store = UserProfileStore.shared

    @State private var currentStep: Int = 1
    @State private var profile: UserProfile = UserProfile()

    private let totalSteps = 3
    private let primaryColor = Color(red: 0.1, green: 0.235, blue: 0.42)
    private let accentColor  = Color(red: 1.0, green: 0.42, blue: 0.21)

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ─────────────────────────────────────────────────────
            VStack(spacing: 16) {
                HStack {
                    // App wordmark
                    Text("SkyAI")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(primaryColor)

                    Spacer()

                    // Step indicator
                    Text("Step \(currentStep) of \(totalSteps)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(accentColor)
                            .frame(
                                width: geo.size.width * (CGFloat(currentStep) / CGFloat(totalSteps)),
                                height: 6
                            )
                            .animation(.spring(response: 0.4), value: currentStep)
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(Color(.systemBackground))

            // ── Step Content ───────────────────────────────────────────────
            TabView(selection: $currentStep) {
                OnboardingStep1View(profile: $profile)
                    .tag(1)

                OnboardingStep2View(profile: $profile)
                    .tag(2)

                OnboardingStep3View(profile: $profile, onComplete: finishOnboarding)
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            // ── Navigation Buttons ─────────────────────────────────────────
            HStack(spacing: 16) {
                // Back
                if currentStep > 1 {
                    Button(action: { withAnimation { currentStep -= 1 } }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(primaryColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(14)
                    }
                    .transition(.opacity)
                }

                // Next / Finish
                if currentStep < totalSteps {
                    Button(action: { withAnimation { currentStep += 1 } }) {
                        HStack(spacing: 6) {
                            Text("Continue")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentColor)
                        .cornerRadius(14)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemGroupedBackground))
    }

    private func finishOnboarding() {
        store.profile = profile
        store.completeOnboarding()
    }
}

#Preview {
    OnboardingContainerView()
}
