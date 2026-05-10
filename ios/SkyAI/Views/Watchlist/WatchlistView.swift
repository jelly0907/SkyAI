import SwiftUI
import Combine

/// Watchlist tab — lists the user's active price watches and past alerts,
/// reads everything from the backend `/watch` API via `WatchlistViewModel`.
///
/// Phase 2 changes vs. the original local-only scaffold:
///   - Renders `WatchResponse` directly (no more local `PriceWatch` shim).
///   - Pull-to-refresh re-runs `GET /watch?user_id=...`.
///   - Per-row "Check now" button calls `POST /watch/{id}/check`.
///   - "Add a watch" CTA points users to the Search tab — watches are now
///     created from the flight detail screen, so the old AddWatchSheet was
///     dropped.
struct WatchlistView: View {
    @StateObject private var viewModel = WatchlistViewModel()

    private let primaryColor = Color(red: 0.1, green: 0.235, blue: 0.42)
    private let accentColor  = Color(red: 1.0, green: 0.42, blue: 0.21)

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.watches.isEmpty && viewModel.pastAlerts.isEmpty {
                    ProgressView("Loading your watchlist…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.watches.isEmpty && viewModel.pastAlerts.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Watchlist")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 22))
                            .tint(accentColor)
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .alert(
                "Couldn't load",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            // Re-fetch every time the tab becomes visible. Watches created
            // from FlightDetailView call APIClient directly without going
            // through this VM, so without an on-appear refresh a brand-new
            // watch wouldn't show up until the user tapped the manual
            // refresh button. Cheap (one GET) and the UX feels right.
            .onAppear {
                Task { await viewModel.refresh() }
            }
        }
    }

    // MARK: - Main list

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 20) {

                // ── Last-check toast ───────────────────────────────────
                if let msg = viewModel.lastCheckMessage {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text(msg)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                        Spacer()
                        Button {
                            viewModel.lastCheckMessage = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // ── Active Watches ─────────────────────────────────────
                if !viewModel.watches.isEmpty {
                    sectionHeader(title: "Active Watches", icon: "eye.fill", count: viewModel.watches.count)

                    ForEach(viewModel.watches) { watch in
                        WatchCard(
                            watch: watch,
                            isBusy: viewModel.rowInFlight == watch.id,
                            onCheckNow: { Task { await viewModel.checkNow(id: watch.id) } },
                            onRemove:   { Task { await viewModel.deleteWatch(id: watch.id) } }
                        )
                        .padding(.horizontal, 20)
                    }
                }

                // ── Past Alerts ────────────────────────────────────────
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
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "bell.slash.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(Color(uiColor: .systemGray4))

            VStack(spacing: 8) {
                Text("No Price Watches Yet")
                    .font(.system(size: 22, weight: .bold))

                Text("Find a flight in Search, then tap the bell on its detail page to start watching the price.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
    }

    // MARK: - Section header

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
    let watch: WatchResponse
    let isBusy: Bool
    let onCheckNow: () -> Void
    let onRemove: () -> Void

    private let accentColor = Color(red: 1.0, green: 0.42, blue: 0.21)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ────────────────────────────────────────────────
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
                    Text(formattedDateRange(departure: watch.departureDate, ret: watch.returnDate))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()
                statusBadge(watch.derivedStatus)

                // Spinner and Menu are mutually exclusive views — keeping the
                // spinner *inside* the Menu's label was unreliable: SwiftUI's
                // Menu is backed by UIKit's UIMenu which caches its trigger
                // label and didn't refresh when isBusy flipped back to false.
                // Keeping them at the same level lets SwiftUI diff cleanly.
                if isBusy {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.leading, 8)
                } else {
                    Menu {
                        Button { onCheckNow() } label: {
                            Label("Check now", systemImage: "arrow.clockwise")
                        }
                        Button(role: .destructive) { onRemove() } label: {
                            Label("Remove watch", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 8)
                }
            }
            .padding(16)

            Divider()

            // ── Price Info ────────────────────────────────────────────
            HStack(alignment: .top, spacing: 0) {
                priceColumn(
                    title: "Last seen",
                    amount: watch.lastPriceUsd,
                    placeholder: "—",
                    color: .primary,
                    label: watch.lastLabel
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().frame(height: 60)

                priceColumn(
                    title: "Alert when",
                    amount: watch.targetPriceUsd,
                    placeholder: "Any deal",
                    color: accentColor,
                    label: nil
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
            }
            .padding(16)

            // ── Last-checked footer ──────────────────────────────────
            Divider()
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 13))
                    .foregroundColor(.blue)
                Text(footerText)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    onCheckNow()
                } label: {
                    Label("Check", systemImage: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                }
                .disabled(isBusy)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.05))
        }
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .opacity(watch.derivedStatus == .paused ? 0.6 : 1.0)
    }

    private var footerText: String {
        if let last = watch.lastCheckedAt {
            return "Last checked \(relativeTime(from: last))"
        }
        return "Never checked yet — tap Check to run one now."
    }

    private func priceColumn(
        title: String,
        amount: Double?,
        placeholder: String,
        color: Color,
        label: PriceLabel?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            if let amount = amount {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("$")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                    Text(String(format: "%.0f", amount))
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(color)
                }
            } else {
                Text(placeholder)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.top, 6)
            }
            if let label = label {
                Text(label.displayName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: label.badgeColor))
                    .cornerRadius(20)
            }
        }
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
}

// MARK: - Past Alert Row

struct PastAlertRow: View {
    let watch: WatchResponse

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(watch.origin) → \(watch.destination)")
                    .font(.system(size: 15, weight: .bold))
                Text(formattedDateRange(departure: watch.departureDate, ret: watch.returnDate))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if let last = watch.lastPriceUsd {
                    Text("$\(Int(last))")
                        .font(.system(size: 17, weight: .black))
                }
                if watch.triggerCount > 0 {
                    Text("Alerted \(watch.triggerCount)×")
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

// MARK: - Helpers

private let watchDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM d"
    return f
}()

private func formattedDateRange(departure: Date, ret: Date?) -> String {
    let dep = watchDateFormatter.string(from: departure)
    if let ret = ret {
        let r = watchDateFormatter.string(from: ret)
        return "\(dep) – \(r)"
    }
    return dep
}

private func relativeTime(from date: Date) -> String {
    let interval = Date().timeIntervalSince(date)
    if interval < 60 { return "just now" }
    if interval < 3600 { return "\(Int(interval / 60))m ago" }
    if interval < 86_400 { return "\(Int(interval / 3600))h ago" }
    return "\(Int(interval / 86_400))d ago"
}

// PriceLabel.badgeColor returns "#RRGGBB"; convert to a SwiftUI Color.
extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        self = Color(
            red:   Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >>  8) & 0xFF) / 255.0,
            blue:  Double(rgb & 0xFF) / 255.0
        )
    }
}
