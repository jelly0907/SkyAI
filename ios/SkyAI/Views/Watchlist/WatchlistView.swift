import SwiftUI
import Combine

struct WatchlistView: View {
    @StateObject private var viewModel = WatchlistViewModel()
    @State private var showAddWatch = false

    private let primaryColor = Color(red: 0.1, green: 0.235, blue: 0.42)
    private let accentColor  = Color(red: 1.0, green: 0.42, blue: 0.21)

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.watches.isEmpty && viewModel.pastAlerts.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {

                            // ── Active Watches ─────────────────────────────
                            if !viewModel.watches.isEmpty {
                                sectionHeader(title: "Active Watches", icon: "eye.fill", count: viewModel.watches.count)

                                ForEach(viewModel.watches) { watch in
                                    WatchCard(
                                        watch: watch,
                                        onPause: { viewModel.togglePause(id: watch.id) },
                                        onRemove: { viewModel.removeWatch(id: watch.id) }
                                    )
                                    .padding(.horizontal, 20)
                                }
                            }

                            // ── Past Alerts ────────────────────────────────
                            if !viewModel.pastAlerts.isEmpty {
                                sectionHeader(title: "Past Alerts", icon: "clock.arrow.circlepath", count: viewModel.pastAlerts.count)

                                ForEach(viewModel.pastAlerts) { watch in
                                    PastAlertRow(watch: watch)
                                        .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Watchlist")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddWatch = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .tint(accentColor)
                    }
                }
            }
            .sheet(isPresented: $showAddWatch) {
                AddWatchSheet(onAdd: { watch in
                    viewModel.addWatch(watch)
                    showAddWatch = false
                })
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "bell.slash.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(Color(uiColor: .systemGray4))

            VStack(spacing: 8) {
                Text("No Price Watches Yet")
                    .font(.system(size: 22, weight: .bold))

                Text("Add a watch and we'll alert you the moment a flight hits your target price.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button(action: { showAddWatch = true }) {
                Label("Watch a Route", systemImage: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(accentColor)
                    .cornerRadius(14)
            }
            Spacer()
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String, count: Int) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accentColor)
            Text(title)
                .font(.system(size: 18, weight: .bold))
            Text("(\(count))")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }
}

// MARK: - Watch Card

struct WatchCard: View {
    let watch: PriceWatch
    let onPause: () -> Void
    let onRemove: () -> Void

    @State private var showOptions = false
    private let primaryColor = Color(red: 0.1, green: 0.235, blue: 0.42)
    private let accentColor  = Color(red: 1.0, green: 0.42, blue: 0.21)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ─────────────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(watch.origin)
                            .font(.system(size: 18, weight: .black))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(watch.destination)
                            .font(.system(size: 18, weight: .black))
                    }
                    Text("\(watch.destinationCity) · \(watch.departureRange)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status badge
                statusBadge(watch.status)

                // Options menu
                Menu {
                    Button(action: onPause) {
                        Label(watch.status == .paused ? "Resume" : "Pause", systemImage: watch.status == .paused ? "play.fill" : "pause.fill")
                    }
                    Button(role: .destructive, action: onRemove) {
                        Label("Remove Watch", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 8)
            }
            .padding(16)

            Divider()

            // ── Price Info ─────────────────────────────────────────────────
            HStack(alignment: .top, spacing: 0) {
                // Current price
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current best")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("$")
                            .font(.system(size: 14, weight: .semibold))
                        Text(String(format: "%.0f", watch.currentBestPrice))
                            .font(.system(size: 26, weight: .black))
                    }
                    trendBadge(watch.trend)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().frame(height: 60)

                // Alert threshold
                VStack(alignment: .leading, spacing: 4) {
                    Text("Alert when")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("$")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(accentColor)
                        Text(String(format: "%.0f", watch.alertThreshold))
                            .font(.system(size: 26, weight: .black))
                            .foregroundColor(accentColor)
                    }
                    if let low = watch.predictedLow {
                        Text("Predicted low: $\(Int(low))")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
            }
            .padding(16)

            // ── Predicted low date ─────────────────────────────────────────
            if let lowDate = watch.predictedLowDate {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                    Text("Predicted low around \(lowDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.05))
            }
        }
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .opacity(watch.status == .paused ? 0.6 : 1.0)
    }

    private func statusBadge(_ status: WatchStatus) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case .active:    return ("● Active", .green)
            case .paused:    return ("⏸ Paused", .orange)
            case .triggered: return ("🔔 Triggered", .blue)
            case .expired:   return ("Expired", .gray)
            }
        }()
        return Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .cornerRadius(20)
    }

    private func trendBadge(_ trend: PriceTrend) -> some View {
        let (icon, color): (String, Color) = {
            switch trend {
            case .falling:  return ("arrow.down.right", .green)
            case .rising:   return ("arrow.up.right", .red)
            case .stable:   return ("arrow.right", .blue)
            case .volatile: return ("arrow.up.arrow.down", .orange)
            }
        }()
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(trend.rawValue.capitalized)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .cornerRadius(20)
    }
}

// MARK: - Past Alert Row

struct PastAlertRow: View {
    let watch: PriceWatch
    private let accentColor = Color(red: 1.0, green: 0.42, blue: 0.21)

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(watch.origin) → \(watch.destination)")
                    .font(.system(size: 15, weight: .bold))
                Text("\(watch.destinationCity) · \(watch.departureRange)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("$\(Int(watch.currentBestPrice))")
                    .font(.system(size: 17, weight: .black))
                if watch.savings > 0 {
                    Text("↓\(watch.savingsPct)% saved")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
    }
}

// MARK: - Add Watch Sheet

struct AddWatchSheet: View {
    let onAdd: (PriceWatch) -> Void

    @State private var origin = ""
    @State private var destination = ""
    @State private var dateRange = ""
    @State private var alertPrice = ""
    @Environment(\.dismiss) private var dismiss

    private let accentColor = Color(red: 1.0, green: 0.42, blue: 0.21)

    var body: some View {
        NavigationStack {
            Form {
                Section("Route") {
                    HStack {
                        TextField("From (e.g. SFO)", text: $origin)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        Divider()
                        TextField("To (e.g. NRT)", text: $destination)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                    TextField("Dates (e.g. Jul 2026)", text: $dateRange)
                }

                Section("Alert") {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Target price", text: $alertPrice)
                            .keyboardType(.numberPad)
                    }
                    Text("We'll notify you the moment the price hits this amount.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Watch a Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let now = Date()
                        let threshold = Double(alertPrice) ?? 999
                        let currentPrice = threshold * 1.15

                        let watch = PriceWatch(
                            origin: origin.uppercased(),
                            destination: destination.uppercased(),
                            originCity: origin,
                            destinationCity: destination,
                            departureRange: dateRange,
                            currentBestPrice: currentPrice,
                            alertThreshold: threshold,
                            predictedLow: threshold * 0.95,
                            predictedLowDate: Calendar.current.date(byAdding: .day, value: 10, to: now),
                            priceLabel: .fair,
                            trend: .falling,
                            status: .active,
                            createdAt: now,
                            lastCheckedAt: now,
                            airline: nil,
                            priceAtCreation: currentPrice
                        )
                        onAdd(watch)
                    }
                    .disabled(origin.isEmpty || destination.isEmpty || alertPrice.isEmpty)
                    .tint(accentColor)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    WatchlistView()
}
