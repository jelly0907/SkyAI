import SwiftUI

struct FlightDetailView: View {
    let offer: FlightOffer
    /// Optional — the search request that produced this offer. Used to
    /// preserve `adults`, `cabinClass`, `tripType` etc. when creating a
    /// price watch from this screen. When nil (older call sites that
    /// haven't been updated, or previews) we fall back to defaults.
    var searchRequest: SearchRequest? = nil

    @Environment(\.dismiss) var dismiss

    // Watch-this-price state. We talk to APIClient directly instead of
    // taking a WatchlistViewModel dependency: the Watchlist tab refreshes
    // itself on appear, so a fire-and-forget create here is enough — no
    // need for the two screens to share state.
    @State private var isWatching: Bool = false
    @State private var watchConfirmation: String?
    @State private var watchError: String?

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

                            // "Watch this price" — POST /watch with the offer's
                            // route/dates/cabin, target = current price. Goes
                            // into the Watchlist tab on next refresh.
                            Button {
                                Task { await watchThisPrice() }
                            } label: {
                                HStack(spacing: 4) {
                                    if isWatching {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "bell.badge.fill")
                                        Text("Watch")
                                    }
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(accentColor)
                                .cornerRadius(20)
                            }
                            .disabled(isWatching)
                        }

                        Text("Flight Details")
                            .font(.system(size: 28, weight: .bold))
                    }
                    .padding(20)

                    // Route Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeaderView(title: "Route")

                        VStack(spacing: 16) {
                            // Show every segment of the outbound itinerary,
                            // with layover gaps surfaced between them. Was
                            // previously passing only segments.first which
                            // dropped all but the first leg of multi-stop trips.
                            ItineraryBreakdownView(
                                itinerary: offer.outbound,
                                title: "Outbound",
                                subtitle: formatDate(offer.outbound.segments.first?.departureTime ?? Date())
                            )

                            if let inbound = offer.inbound {
                                Divider()
                                    .padding(.vertical, 8)

                                ItineraryBreakdownView(
                                    itinerary: inbound,
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
        // Watch-creation feedback. Two separate alerts so we can distinguish
        // the success path (auto-dismissable confirmation) from the failure
        // path (might need a retry).
        .alert(
            "Watching this price",
            isPresented: Binding(
                get: { watchConfirmation != nil },
                set: { if !$0 { watchConfirmation = nil } }
            )
        ) {
            Button("OK") { watchConfirmation = nil }
        } message: {
            Text(watchConfirmation ?? "")
        }
        .alert(
            "Couldn't create the watch",
            isPresented: Binding(
                get: { watchError != nil },
                set: { if !$0 { watchError = nil } }
            )
        ) {
            Button("OK") { watchError = nil }
        } message: {
            Text(watchError ?? "")
        }
    }

    // MARK: - Watch this price

    private func watchThisPrice() async {
        guard let firstSegment = offer.outbound.segments.first,
              let lastSegment  = offer.outbound.segments.last
        else {
            watchError = "This offer is missing flight info."
            return
        }
        // Roundtrip return date = the inbound's first-segment departure date.
        // For a one-way the offer has only an outbound itinerary and the
        // request will pass nil here, which the backend accepts.
        let returnDate = offer.inbound?.segments.first?.departureAt

        // Carry the original passenger count and cabin class from the
        // search that produced this offer, so the alert tracks the same
        // shopping intent. Falls back to single-adult / segment-cabin if
        // the caller didn't pass a search request (e.g. previews).
        let adults     = searchRequest?.adults     ?? 1
        let cabinClass = searchRequest?.cabinClass ?? firstSegment.cabin

        let request = WatchCreateRequest(
            userId: "demo-user",
            origin: firstSegment.origin,
            destination: lastSegment.destination,
            departureDate: firstSegment.departureAt,
            returnDate: returnDate,
            cabinClass: cabinClass,
            adults: adults,
            maxStops: nil,
            targetPriceUsd: offer.priceBreakdown.totalUsd,
            notifyOnGreatDeal: true
        )

        isWatching = true
        defer { isWatching = false }
        do {
            let watch = try await APIClient.shared.createWatch(request)
            let target = Int(watch.targetPriceUsd ?? offer.priceBreakdown.totalUsd)
            watchConfirmation =
                "We'll alert you the moment \(watch.origin) → \(watch.destination) "
                + "drops to or below $\(target). "
                + "See it in the Watchlist tab."
        } catch let err as SkyAIError {
            watchError = err.errorDescription
                ?? "Couldn't create the watch. Please try again."
        } catch {
            watchError = "Couldn't create the watch. Please try again."
        }
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

/// Renders every segment of an itinerary with layover gaps surfaced
/// between consecutive legs. Replaces the old DetailedSegmentView, which
/// only displayed the first segment.
struct ItineraryBreakdownView: View {
    let itinerary: Itinerary
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // Each segment as its own row, with a "layover" indicator
            // injected between consecutive segments showing the airport
            // and wait duration.
            ForEach(Array(itinerary.segments.enumerated()), id: \.offset) { idx, segment in
                SegmentRowView(segment: segment, legNumber: idx + 1)

                // Layover row between this segment and the next.
                if idx < itinerary.segments.count - 1 {
                    let next = itinerary.segments[idx + 1]
                    LayoverRowView(
                        airport: segment.arrivalAirport,
                        layoverMinutes: layoverMinutes(arrival: segment.arrivalTime, nextDeparture: next.departureTime)
                    )
                }
            }
        }
    }

    private func layoverMinutes(arrival: Date, nextDeparture: Date) -> Int {
        max(0, Int(nextDeparture.timeIntervalSince(arrival) / 60))
    }
}

/// One leg of a multi-stop trip — origin → destination, times, flight #.
struct SegmentRowView: View {
    let segment: Segment
    let legNumber: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Leg \(legNumber)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.1, green: 0.235, blue: 0.42))

                Spacer()

                Text("\(segment.airlineCode) \(segment.flightNumber)")
                    .font(.system(size: 11))
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

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(segment.arrivalAirport)
                        .font(.system(size: 14, weight: .semibold))

                    HStack(spacing: 2) {
                        Text(formatTime(segment.arrivalTime))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                        if isNextDay(departure: segment.departureTime, arrival: segment.arrivalTime) {
                            Text("+1")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color(uiColor: .systemGray6).opacity(0.5))
        .cornerRadius(8)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func isNextDay(departure: Date, arrival: Date) -> Bool {
        Calendar.current.dateComponents([.day], from: departure, to: arrival).day ?? 0 > 0
    }
}

/// Compact row shown between consecutive segments — airport name and
/// layover duration so the user knows how long they're stuck on the ground.
struct LayoverRowView: View {
    let airport: String
    let layoverMinutes: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text("Layover at \(airport)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()

            Text(formattedLayover)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(layoverColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var formattedLayover: String {
        let h = layoverMinutes / 60
        let m = layoverMinutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    /// Tight layover (<60min) is risky — flag in red. >5h is bad UX, flag
    /// in orange. Otherwise neutral gray.
    private var layoverColor: Color {
        if layoverMinutes < 60 { return .red }
        if layoverMinutes > 300 { return .orange }
        return .secondary
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
