import CodexLimitCore
import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: LimitStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let message = store.snapshot.errorMessage {
                errorBanner(message)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(store.snapshot.windows) { window in
                    LimitWindowCard(window: window)
                }
            }

            statusCard

            Spacer(minLength: 0)

            footer
        }
        .padding(18)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            appLogo

            VStack(alignment: .leading, spacing: 3) {
                Text("Codex Limit Widget")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                Text("\(store.snapshot.planLabel) reset watcher")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(store.snapshot.availableResetCount)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(store.snapshot.availableResetCount == 1 ? "reset banked" : "resets banked")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.separator.opacity(0.35))
        }
    }

    @ViewBuilder
    private var appLogo: some View {
        if let image = NSImage(named: "AppLogo") {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.separator.opacity(0.35))
                }
        } else {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 54, height: 54)
                .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: store.statusSymbolName)
                .font(.title2)
                .foregroundStyle(statusTint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text(store.snapshot.statusTitle)
                    .font(.headline)
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(statusTint.opacity(0.35))
        }
    }

    private var footer: some View {
        HStack {
            Label("Updates every 1 min", systemImage: "clock")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(CodexLimitDateFormatting.checked(store.snapshot.checkedAt))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                Task {
                    await store.refresh()
                }
            } label: {
                Label(store.isRefreshing ? "Refreshing" : "Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(store.isRefreshing)
        }
    }

    private var statusTint: Color {
        if store.snapshot.isNotChecked {
            return .secondary
        }
        if store.snapshot.errorMessage != nil, store.snapshot.windows.isEmpty {
            return .orange
        }
        if let weekly = store.snapshot.weeklyWindow?.remainingPercent, weekly <= 20 {
            return .green
        }
        if let fiveHour = store.snapshot.fiveHourWindow?.remainingPercent, fiveHour <= 12 {
            return .blue
        }
        return .teal
    }

    private var statusMessage: String {
        if store.snapshot.isNotChecked {
            return "Press Refresh or wait for the first automatic check."
        }
        if store.snapshot.errorMessage != nil, store.snapshot.windows.isEmpty {
            return "Open Codex Desktop and make sure you are signed in."
        }
        if store.snapshot.availableResetCount > 0 {
            return "The widget opens this reset watcher when clicked."
        }
        return "No banked reset is available right now. Keep an eye on the usage windows."
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .lineLimit(3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.orange.opacity(0.30))
        }
    }
}

private struct LimitWindowCard: View {
    let window: LimitWindowSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label(window.title, systemImage: iconName)
                    .font(.headline)
                Spacer()
                Text(percentText(window.remainingPercent))
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            ProgressView(value: Double(window.remainingPercent ?? 0), total: 100)
                .tint(tint)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("Used").foregroundStyle(.secondary)
                    Text(percentText(window.usedPercent)).monospacedDigit()
                }
                GridRow {
                    Text("Resets").foregroundStyle(.secondary)
                    Text(CodexLimitDateFormatting.duration(seconds: window.resetAfterSeconds))
                }
                GridRow {
                    Text("At").foregroundStyle(.secondary)
                    Text(CodexLimitDateFormatting.resetTime(window.resetDate))
                }
            }
            .font(.subheadline)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.separator.opacity(0.35))
        }
    }

    private var iconName: String {
        switch window.kind {
        case .fiveHour:
            return "clock"
        case .weekly:
            return "calendar"
        case .generic:
            return "gauge"
        }
    }

    private var tint: Color {
        guard let remaining = window.remainingPercent else {
            return .secondary
        }
        if remaining <= 15 {
            return .red
        }
        if remaining <= 30 {
            return .orange
        }
        return .green
    }

    private func percentText(_ value: Int?) -> String {
        guard let value else {
            return "-"
        }
        return "\(value)%"
    }
}
