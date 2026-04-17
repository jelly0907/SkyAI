import SwiftUI
import Combine

@main
struct SkyAIApp: App {
    @StateObject private var profileStore = UserProfileStore.shared

    var body: some Scene {
        WindowGroup {
            if profileStore.isOnboardingComplete {
                ContentView()
                    .environmentObject(profileStore)
            } else {
                OnboardingContainerView()
                    .environmentObject(profileStore)
            }
        }
    }
}
