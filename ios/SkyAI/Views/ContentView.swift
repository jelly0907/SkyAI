import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject private var profileStore: UserProfileStore
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)

            WatchlistView()
                .tabItem {
                    Label("Watchlist", systemImage: "bell.fill")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(3)
        }
        .tint(Color(red: 1.0, green: 0.42, blue: 0.21))
        .onReceive(NotificationCenter.default.publisher(for: .switchToSearchTab)) { _ in
            selectedTab = 1
        }
    }
}

// WatchlistView and ProfileView are now in their own files:
// Views/Watchlist/WatchlistView.swift
// Views/Profile/ProfileView.swift

#Preview {
    ContentView()
}
