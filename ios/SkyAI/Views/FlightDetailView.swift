import SwiftUI

struct FlightDetailView: View {
    let offer: FlightOffer
    @Environment(\.dismiss) var dismiss

    private let primaryColor = Color(red: 0.1, green: 0.235, blue: 0.42)
    private let accentColor = Color(red: 1.0, green: 0.42, blue: 0.21)

    var body: some View {
        // Note: do NOT wrap this view in its own NavigationStack. This view
        // is pushed into SearchView's NavigationStack via a NavigationLink,
        // and nesting a second NavigationStack breaks the parent's
        // navigationDestination(for: SearchRequest.self) lookup after
        // popping back — the next programmatic push silently fails with
        // "no matching navigationDestination declaration visible".
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Button(action: { dismiss() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(primaryColor)
                            }

                            Spacer()
                        }

                        Text("Flight Details")
                            .font(.system(size: 28, weight: .bold))
                    }
                    .padding(20)

                    // Route Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeaderView(title: "Route")

                        VStack(spacing: 16) {
                            DetailedSegmentView(
                                segment: offer.outbound.segments.first,
                                title: "Outbound",
                                subtitle: formatDate(offer.outbound.segments.first?.departureTime ?? Date())
                            )

                            if let inbound = offer.inbound {
                                Divider()
                                    .padding(.vertical, 8)

                                DetailedSegmentView(
                                    segment: inbound.segments.first,
                                    title: "Return",
                                    subtitle: formatDate(inbound.segments.first?.departureTime ?? Date())
                                )
                            }

                            Divider()

                            HStack {
                                Label("Total Duration", systemImage: "clock")
                                    .font(.system(size: 14, weight: .semibold))

                                Spacer()

                                Text(offer.totalDuration)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(primaryColor)
                            }
                            .padding(12)
                            .background(Color(uiColor: .systemGray6))
                            .cornerRadius(8)
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)

                    // Price Intelligence Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeaderView(title: "Price Intelligence")

                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                PriceBadgeView(
                                    label: offer.priceIntelligence.priceLabel.displayName,
                                    label_enum: offer.priceIntelligence.priceLabel
                                )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Percentile Rank")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.secondary)

                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(uiColor: .systemGray6))

                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(accentColor)
                                                .frame(width: geo.size.width * CGFloat(offer.priceIntelligence.percentileRank))
                                        }
                                        .frame(height: 6)
                                    }
                                    .frame(height: 6)

                                    Text("\(Int(offer.priceIntelligence.percentileRank * 100))th percentile")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label("Price Trend", systemImage: trendIcon)
                                        .font(.system(size: 14, weight: .semibold))

                                    Spacer()

                                    Text(offer.priceIntelligence.trend.rawValue.capitalized)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(trendColor)
                                }

                                if let savingsAmount = offer.priceIntelligence.savingsAmount, savingsAmount > 0 {
                                    HStack {
                                        Label("Potential Savings", systemImage: "dollarsign.circle")
                                            .font(.system(size: 14, weight: .semibold))

                                        Spacer()

                                        Text("$\(Int(savingsAmount)) (\(Int(offer.priceIntelligence.savingsPercent ?? 0))%)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.green)
                                    }
                                }
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recommendation")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)

                                HStack(spacing: 8) {
                                    Image(systemName: recommendationIcon)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(primaryColor)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(offer.priceIntelligence.recommendedAction.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(.system(size: 14, weight: .semibold))

                                        Text(offer.priceIntelligence.explanation)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                            .lineLimit(3)
                                    }

                                    Spacer()
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)

                    // Fare Details Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeaderView(title: "Fare Details")

                        VStack(spacing: 12) {
                            DetailRowView(
                                label: "Refundable",
                                value: offer.fareConditions.refundable ? "Yes" : "No",
                                icon: "checkmark.circle"
                            )

                            DetailRowView(
                                label: "Changes Allowed",
                                value: offer.fareConditions.changeable ? "Yes" : "No",
                                icon: "pencil.circle"
                            )

                            DetailRowView(
                                label: "Baggage (Carry-on)",
                                value: offer.baggageInfo.carryon,
                                icon: "briefcase"
                            )

                            DetailRowView(
                                label: "Checked Bags",
                                value: "\(offer.baggageInfo.checkedBags) bag\(offer.baggageInfo.checkedBags == 1 ? "" : "s")",
                                icon: "bag"
                            )

                            DetailRowView(
                                label: "Available Seats",
                                value: "\(offer.availableSeats)",
                                icon: "chair"
                            )

                            DetailRowView(
                                label: "On-Time Rate",
                                value: "N/A",
                                icon: "clock.badge.checkmark"
                            )
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)

                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "arrow.up.right")
                                Text("Book on Airline")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(primaryColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        Button(action: {}) {
                            HStack {
                                Image(systemName: "bell.badge")
                                Text("Set Price Alert")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Color(uiColor: .systemGray6))
                            .foregroundColor(primaryColor)
                            .cornerRadius(12)
                        }
                    }
                    .padding(20)
                }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var trendIcon: String {
        switch offer.priceIntelligence.trend {
        case .rising:
            return "arrow.up"
        case .falling:
            return "arrow.down"
        case .stable:
            return "minus"
        case .volatile:
            return "shuffle"
        }
    }

    private var trendColor: Color {
        switch offer.priceIntelligence.trend {
        case .rising:
            return .red
        case .falling:
            return .green
        case .stable:
            return .gray
        case .volatile:
            return .orange
        }
    }

    private var recommendationIcon: String {
        switch offer.priceIntelligence.recommendedAction {
        case .buyNow:
            return "bolt.fill"
        case .wait:
            return "hourglass"
        case .setAlert:
            return "bell.fill"
        case .monitor:
            return "eye.fill"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

struct DetailedSegmentView: View {
    let segment: Segment?
    let title: String
    let subtitle: String

    var body: some View {
        if let segment = segment {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(segment.departureAirport)
                            .font(.system(size: 14, weight: .semibold))

                        Text(formatTime(segment.departureTime))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .center, spacing: 0) {
                        Text("\(segment.durationMinutes / 60)h \(segment.durationMinutes % 60)m")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)

                        Divider()

                        Text("\(segment.stops) stop\(segment.stops == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(segment.arrivalAirport)
                            .font(.system(size: 14, weight: .semibold))

                        Text(formatTime(segment.arrivalTime))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct SectionHeaderView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
    }
}

struct DetailRowView: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.1, green: 0.235, blue: 0.42))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    FlightDetailView(offer: FlightOffer(
        offerId: "1",
        source: "mock",
        itineraries: [
            Itinerary(
                segments: [
                    Segment(
                        origin: "SFO",
                        destination: "NRT",
                        departureAt: Date(),
                        arrivalAt: Date().addingTimeInterval(38000),
                        carrierCode: "NH",
                        flightNumber: "NH107",
                        aircraftCode: "787",
                        durationMinutes: 630,
                        cabin: .economy
                    )
                ],
                totalDurationMinutes: 630,
                stops: 0
            )
        ],
        priceBreakdown: PriceBreakdown(
            totalUsd: 800,
            baseFareUsd: 650,
            taxesUsd: 100,
            feesUsd: 50,
            perAdultUsd: 800
        ),
        baggageInfo: BaggageInfo(
            checkedBagsIncluded: 1,
            carryOnIncluded: true,
            checkedBagWeightKg: 23
        ),
        fareConditions: FareConditions(
            isRefundable: true,
            changeFeeUsd: 0,
            fareClass: "Y"
        ),
        seatsRemaining: 5,
        priceIntelligence: PriceIntelligence(
            priceLabel: .steal,
            pricePercentile: 90,
            savingsVsMedianUsd: 200,
            savingsPct: 19,
            trend: .falling,
            forecast7dUsd: nil,
            forecast14dUsd: nil,
            action: .buyNow,
            actionReason: "Great price right now",
            badgeText: "STEAL",
            confidence: 0.9
        ),
        bookingUrl: "https://example.com",
        lastTicketingDate: nil
    ))
}
