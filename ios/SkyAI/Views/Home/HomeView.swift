import SwiftUI
import Combine

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var profileStore: UserProfileStore
    @State private var searchQuery = ""
    @State private var navigationPath = NavigationPath()

    private let primaryColor = Color(red: 0.1, green: 0.235, blue: 0.42)
    private let accentColor  = Color(red: 1.0, green: 0.42, blue: 0.21)

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {

                    // ── Hero Header ────────────────────────────────────────
                    heroHeader

                    // ── Quick Search Bar ───────────────────────────────────
                    quickSearchBar

                    if viewModel.isLoading {
                        // Skeleton placeholders
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonCard()
                                .padding(.horizontal, 20)
                        }
                    } else {
                        // ── Feed Sections ──────────────────────────────────
                        ForEach(viewModel.sections) { section in
                            feedSection(section)
                        }
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable { await viewModel.refresh() }
            .navigationBarHidden(true)
            .navigationDestination(for: SearchRequest.self) { request in
                ResultsView(searchRequest: request)
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Background gradient
            LinearGradient(
                colors: [primaryColor, primaryColor.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 180)
            .ignoresSafeArea(edges: .top)

            // Decorative airplane
            Image(systemName: "airplane")
                .font(.system(size: 120, weight: .ultraLight))
                .foregroundColor(.white.opacity(0.07))
                .rotationEffect(.degrees(45))
                .offset(x: 180, y: -20)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.greetingText + ",")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))

                Text(viewModel.userFirstName.isEmpty ? "Traveler ✈️" : "\(viewModel.userFirstName) ✈️")
                    .font(.system(size: 30, weight: .black))
                    .foregroundColor(.white)

                Text("Where are you flying next?")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Quick Search Bar

    private var quickSearchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            Text("Search flights or cities...")
                .font(.system(size: 16))
                .foregroundColor(.secondary)

            Spacer()

            Image(systemName: "mic.fill")
                .foregroundColor(accentColor)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .padding(.horizontal, 20)
        .padding(.top, -14)  // Pull up over the hero gradient
        // Tapping the search bar takes user to Search tab
        .onTapGesture {
            // Post notification to switch to search tab
            NotificationCenter.default.post(name: .switchToSearchTab, object: nil)
        }
    }

    // MARK: - Feed Section

    @ViewBuilder
    private func feedSection(_ section: FeedSection) -> some View {
        VStack(alignment: .leading, spacing: 14) {

            // Section header
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: section.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)

                    if let sub = section.subtitle {
                        Text(sub)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button("See all") {}
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(primaryColor)
            }
            .padding(.horizontal, 20)

            // Section content
            switch section.sectionType {
            case .dealCards, .loyaltyRoutes:
                VStack(spacing: 12) {
                    ForEach(section.dealCards) { card in
                        HomeDealCardView(card: card) {
                            navigateToSearch(for: card)
                        }
                        .padding(.horizontal, 20)
                    }
                }

            case .horizontalChips:
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(section.routeChips) { chip in
                            RouteChipView(chip: chip) {
                                navigateToSearch(for: chip)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Navigation Helpers

    private func navigateToSearch(for card: DealCard) {
        let request = SearchRequest(
            originCode: card.origin,
            destinationCode: card.destination,
            departureDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        )
        navigationPath.append(request)
    }

    private func navigateToSearch(for chip: RouteChip) {
        let homeAirport = "SFO" // In production: from UserProfile
        let request = SearchRequest(
            originCode: homeAirport,
            destinationCode: chip.destination,
            departureDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        )
        navigationPath.append(request)
    }
}

// MARK: - Route Chip View

struct RouteChipView: View {
    let chip: RouteChip
    let onTap: () -> Void

    private let accentColor = Color(red: 1.0, green: 0.42, blue: 0.21)

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(chip.city)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)

                Text(chip.destination)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                Text("$\(Int(chip.price))")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.primary)

                if chip.priceLabel == .steal || chip.priceLabel == .greatDeal {
                    Text(chip.priceLabel == .steal ? "🔥 STEAL" : "✅ DEAL")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(chip.priceLabel == .steal ? accentColor : Color.green)
                        .cornerRadius(20)
                }
            }
            .frame(width: 110, height: 120)
            .padding(14)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Skeleton Card

struct SkeletonCard: View {
    @State private var opacity: Double = 0.4

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemGray5))
            .frame(height: 160)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    opacity = 0.8
                }
            }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let switchToSearchTab = Notification.Name("switchToSearchTab")
}

#Preview {
    HomeView()
        .environmentObject(UserProfileStore.shared)
}
