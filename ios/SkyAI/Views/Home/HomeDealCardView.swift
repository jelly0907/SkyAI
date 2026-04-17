import SwiftUI

/// A large deal card displayed in the home feed vertical sections.
struct HomeDealCardView: View {
    let card: DealCard
    let onTap: () -> Void

    private let primaryColor = Color(red: 0.1, green: 0.235, blue: 0.42)
    private let accentColor  = Color(red: 1.0, green: 0.42, blue: 0.21)

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Top row: badge + airline ───────────────────────────────
                HStack {
                    if !card.badgeText.isEmpty {
                        Text(card.badgeText)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(badgeColor(for: card.priceLabel))
                            .cornerRadius(20)
                    }

                    Spacer()

                    Text(card.airline)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(primaryColor)
                        .cornerRadius(6)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

                // ── Route row ──────────────────────────────────────────────
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.origin)
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(.primary)
                        Text("Origin")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 4) {
                        // Flight line with stop dots
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color(uiColor: .systemGray4))
                                .frame(height: 1)

                            if card.stops > 0 {
                                Circle()
                                    .fill(Color(uiColor: .systemGray3))
                                    .frame(width: 6, height: 6)
                            } else {
                                Image(systemName: "airplane")
                                    .font(.system(size: 12))
                                    .foregroundColor(primaryColor)
                                    .rotationEffect(.degrees(45))
                            }

                            Rectangle()
                                .fill(Color(uiColor: .systemGray4))
                                .frame(height: 1)
                        }

                        Text(card.stops == 0 ? "Direct · \(card.durationText)" : "\(card.stops) stop · \(card.durationText)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(card.destination)
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(.primary)
                        Text(card.destinationCity)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 14)

                Divider()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                // ── Bottom row: price + dates + action ─────────────────────
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("$")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            Text(String(format: "%.0f", card.price))
                                .font(.system(size: 26, weight: .black))
                                .foregroundColor(.primary)
                        }

                        if let pct = card.savingsPct {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.green)
                                Text("\(pct)% vs avg")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        }

                        Text(card.departureDate)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Trend + action
                    VStack(alignment: .trailing, spacing: 6) {
                        trendPill(card.trend)
                        actionButton(card.actionType)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sub-views

    private func trendPill(_ trend: PriceTrend) -> some View {
        HStack(spacing: 4) {
            Image(systemName: trendIcon(trend))
                .font(.system(size: 10, weight: .bold))
            Text(trend.rawValue.capitalized)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(trendColor(trend))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(trendColor(trend).opacity(0.12))
        .cornerRadius(20)
    }

    private func actionButton(_ action: ActionType) -> some View {
        Group {
            switch action {
            case .buyNow:
                Text("Book Now →")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .cornerRadius(20)

            case .wait:
                Text("Watch 📉")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(primaryColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(primaryColor.opacity(0.1))
                    .cornerRadius(20)

            case .setAlert:
                Text("Set Alert 🔔")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(accentColor.opacity(0.1))
                    .cornerRadius(20)

            case .monitor:
                Text("Watching 👀")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(20)
            }
        }
    }

    // MARK: - Helpers

    private func badgeColor(for label: PriceLabel) -> Color {
        switch label {
        case .steal:     return Color(red: 1.0, green: 0.42, blue: 0.21)
        case .greatDeal: return .green
        case .fair:      return Color(uiColor: .systemGray)
        case .expensive: return .orange
        case .overpriced: return .red
        case .unknown:   return Color(uiColor: .systemGray4)
        }
    }

    private func trendIcon(_ trend: PriceTrend) -> String {
        switch trend {
        case .rising:   return "arrow.up.right"
        case .falling:  return "arrow.down.right"
        case .stable:   return "arrow.right"
        case .volatile: return "arrow.up.arrow.down"
        }
    }

    private func trendColor(_ trend: PriceTrend) -> Color {
        switch trend {
        case .rising:   return .red
        case .falling:  return .green
        case .stable:   return .blue
        case .volatile: return .orange
        }
    }
}
