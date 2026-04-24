import SwiftUI
import Combine

struct ResultsView: View {
    let searchRequest: SearchRequest
    @StateObject private var viewModel = ResultsViewModel()
    @State private var selectedOffer: FlightOffer? = nil
    @Environment(\.dismiss) var dismiss

    private let primaryColor = Color(red: 0.1, green: 0.235, blue: 0.42)
    private let accentColor = Color(red: 1.0, green: 0.42, blue: 0.21)

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(primaryColor)
                        }

                        Spacer()

                        Text("\(searchRequest.originCode) → \(searchRequest.destinationCode)")
                            .font(.system(size: 16, weight: .semibold))

                        Spacer()

                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                            .opacity(0)
                    }

                    HStack(spacing: 8) {
                        Text(formatDate(searchRequest.departureDate))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                        Divider()
                            .frame(maxWidth: 20)

                        Text("\(searchRequest.adults) \(searchRequest.adults == 1 ? "Adult" : "Adults")")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }
                .padding(16)
                .background(Color(uiColor: .systemGray6))

                // Sort Picker
                Picker("Sort", selection: Binding(
                    get: { viewModel.sortOption },
                    set: { viewModel.sort(by: $0) }
                )) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(16)

                // Content
                if viewModel.isLoading {
                    SkeletonLoadingView()
                } else if let error = viewModel.errorMessage {
                    ErrorStateView(
                        message: error,
                        action: {
                            Task {
                                await viewModel.retry(request: searchRequest)
                            }
                        }
                    )
                } else if viewModel.offers.isEmpty {
                    EmptyStateView()
                } else {
                    ZStack(alignment: .bottom) {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.offers) { offer in
                                NavigationLink(destination: FlightDetailView(offer: offer)) {
                                    FlightCardView(offer: offer)
                                }
                            }

                            Spacer()
                                .frame(height: 100)
                        }
                        .padding(16)

                        // Pareto Bar
                        if let cheapest = viewModel.offers.min(by: { $0.price < $1.price }),
                           let fastest = viewModel.offers.min(by: { $0.outbound.durationMinutes < $1.outbound.durationMinutes }),
                           let bestDeal = viewModel.offers.max(by: { $0.priceIntelligence.percentileRank < $1.priceIntelligence.percentileRank }) {
                            ParetoBarView(
                                cheapestPrice: cheapest.price,
                                fastestDuration: fastest.outbound.formattedDuration,
                                bestDealLabel: bestDeal.priceIntelligence.priceLabel.displayName
                            )
                        }
                    }
                }

                Spacer()
            }
            .navigationBarBackButtonHidden(true)
        }
        .task {
            await viewModel.load(request: searchRequest)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct SkeletonLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .systemGray6))
                    .frame(height: 140)
                    .shimmer()
            }

            Spacer()
        }
        .padding(16)
    }
}

struct ErrorStateView: View {
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text("Oops!")
                .font(.system(size: 20, weight: .semibold))

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: action) {
                Text("Try Again")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color(red: 1.0, green: 0.42, blue: 0.21))
                    .cornerRadius(8)
            }

            Spacer()
        }
        .padding(20)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No flights found")
                .font(.system(size: 20, weight: .semibold))

            Text("Try adjusting your search criteria")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(20)
    }
}

struct ParetoBarView: View {
    let cheapestPrice: Double
    let fastestDuration: String
    let bestDealLabel: String

    var body: some View {
        VStack(spacing: 12) {
            Divider()

            HStack(spacing: 12) {
                ParetoChipView(
                    icon: "dollarsign.circle.fill",
                    label: "Cheapest",
                    value: "$\(Int(cheapestPrice))",
                    color: Color(red: 0.1, green: 0.235, blue: 0.42)
                )

                ParetoChipView(
                    icon: "timer",
                    label: "Fastest",
                    value: fastestDuration,
                    color: Color(red: 1.0, green: 0.42, blue: 0.21)
                )

                ParetoChipView(
                    icon: "star.fill",
                    label: "Best Deal",
                    value: bestDealLabel,
                    color: Color.green
                )
            }
        }
        .padding(12)
        .background(Color(uiColor: .systemGray6))
    }
}

struct ParetoChipView: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))

                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(color)

            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var isShimmering = false

    func body(content: Content) -> some View {
        content
            .opacity(isShimmering ? 0.5 : 1.0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isShimmering = true
                }
            }
    }
}

#Preview {
    ResultsView(searchRequest: SearchRequest())
}
