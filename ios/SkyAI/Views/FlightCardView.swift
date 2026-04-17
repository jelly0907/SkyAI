import SwiftUI

struct FlightCardView: View {
    let offer: FlightOffer

    private let primaryColor = Color(red: 0.1, green: 0.235, blue: 0.42)
    private let accentColor = Color(red: 1.0, green: 0.42, blue: 0.21)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top Row: Badge + Airline + Details
            HStack(spacing: 12) {
                // Deal Badge
                PriceBadgeView(label: offer.priceLabel, label_enum: offer.priceIntelligence.priceLabel)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(offer.outbound.segments.first?.airlineCode ?? "N/A")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text(offer.outbound.segments.first?.flightNumber ?? "N/A")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    Text("\(offer.outbound.totalStops) stop\(offer.outbound.totalStops == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if let savingsPercent = offer.priceIntelligence.savingsPercent, savingsPercent > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 10, weight: .semibold))

                            Text("\(Int(savingsPercent))%")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.green)
                    }
                }
            }

            Divider()

            // Route with times
            VStack(spacing: 8) {
                RouteSegmentView(segment: offer.outbound.segments.first)

                if let inbound = offer.inbound {
                    Divider()
                        .padding(.vertical, 4)

                    RouteSegmentView(segment: inbound.segments.first, isReturn: true)
                }
            }

            Divider()

            // Duration, Stops, Price Row
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(offer.outbound.formattedDuration)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("\(offer.outbound.totalStops) stops")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Price and Action
                HStack(spacing: 12) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("$\(Int(offer.price))")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(primaryColor)

                        if let savingsAmount = offer.priceIntelligence.savingsAmount, savingsAmount > 0 {
                            Text("Save $\(Int(savingsAmount))")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                        }
                    }

                    VStack(spacing: 6) {
                        if offer.priceIntelligence.recommendedAction == .buyNow {
                            Button(action: {}) {
                                HStack(spacing: 4) {
                                    Text("Buy Now")
                                        .font(.system(size: 12, weight: .semibold))

                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .background(Color.green)
                                .cornerRadius(6)
                            }
                        } else {
                            Button(action: {}) {
                                HStack(spacing: 4) {
                                    Text("Watch")
                                        .font(.system(size: 12, weight: .semibold))

                                    Image(systemName: "eye.fill")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .background(accentColor)
                                .cornerRadius(6)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}

struct PriceBadgeView: View {
    let label: String
    let label_enum: PriceLabel

    var badgeColor: Color {
        switch label_enum {
        case .steal:
            return Color(red: 1.0, green: 0.42, blue: 0.21)
        case .greatDeal:
            return Color.green
        case .fair:
            return Color.gray
        case .expensive:
            return Color(red: 0.96, green: 0.62, blue: 0.06)
        case .overpriced:
            return Color.red
        case .unknown:
            return Color(red: 0.83, green: 0.84, blue: 0.86)
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor)
            .cornerRadius(6)
    }
}

struct RouteSegmentView: View {
    let segment: Segment?
    let isReturn: Bool

    init(segment: Segment?, isReturn: Bool = false) {
        self.segment = segment
        self.isReturn = isReturn
    }

    var body: some View {
        if let segment = segment {
            HStack(spacing: 12) {
                VStack(alignment: .center, spacing: 2) {
                    Text(segment.departureAirport)
                        .font(.system(size: 13, weight: .semibold))

                    Text(formatTime(segment.departureTime))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(width: 50, alignment: .center)

                VStack(alignment: .center, spacing: 4) {
                    HStack(spacing: 0) {
                        Divider()
                            .frame(maxHeight: 1)

                        Image(systemName: "airplane")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(width: 24)

                        Divider()
                            .frame(maxHeight: 1)
                    }

                    if isReturn {
                        Text("Return")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .center, spacing: 2) {
                    Text(segment.arrivalAirport)
                        .font(.system(size: 13, weight: .semibold))

                    HStack(spacing: 2) {
                        Text(formatTime(segment.arrivalTime))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        if isNextDay(departure: segment.departureTime, arrival: segment.arrivalTime) {
                            Text("+1")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(width: 50, alignment: .center)

                Spacer()
            }
        }
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

#Preview {
    VStack(spacing: 12) {
        FlightCardView(offer: FlightOffer(
            id: "1",
            outbound: Itinerary(
                segments: [
                    Segment(
                        departureAirport: "SFO",
                        departureTime: Date(),
                        arrivalAirport: "NRT",
                        arrivalTime: Date().addingTimeInterval(38000),
                        flightNumber: "NH107",
                        airlineCode: "NH",
                        aircraft: "787",
                        durationMinutes: 630,
                        stops: 0
                    )
                ],
                durationMinutes: 630
            ),
            inbound: nil,
            priceBreakdown: PriceBreakdown(basePrice: 650, taxes: 100, fees: 50, currency: "USD"),
            baggageInfo: BaggageInfo(carryon: "1 bag", checkedBags: 1, checkedWeight: "23kg"),
            fareConditions: FareConditions(refundable: true, changeable: true, minStayDays: nil),
            priceIntelligence: PriceIntelligence(
                priceLabel: .steal,
                percentileRank: 0.9,
                historicalAverage: 850,
                historicalMin: 600,
                historicalMax: 1200,
                savingsAmount: 200,
                savingsPercent: 19,
                trend: .falling,
                recommendedAction: .buyNow,
                explanation: "Great price right now"
            ),
            bookingUrl: "https://example.com",
            availableSeats: 5
        ))
    }
    .padding(16)
    .background(Color(.systemGray6))
}
