import AppKit
import CodexLimitCore
import SwiftUI

struct MenuBarStatusView: View {
    @ObservedObject var store: LimitStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Codex limits")
                        .font(.headline)
                    Text(store.snapshot.configurationLine ?? store.snapshot.planLabel)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Text(CodexLimitDateFormatting.checked(store.snapshot.checkedAt))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Refreshing Codex limits")
                        .accessibilityValue("Update in progress")
                } else {
                    Text(store.snapshot.compactBalance)
                        .font(.headline)
                        .monospacedDigit()
                        .accessibilityLabel("Balance")
                        .accessibilityValue(store.snapshot.compactBalance)
                }
            }

            ScrollView {
                if store.snapshot.windows.isEmpty {
                    Text("No usage windows available")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                } else {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(store.snapshot.windows) { window in
                            menuWindowRow(window)
                        }
                    }
                }
            }
            .frame(maxHeight: 240)
            .accessibilityLabel("Usage windows")

            HStack {
                Image(systemName: store.statusSymbolName)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(statusPresentation.title)
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(statusPresentation.title)
            .accessibilityValue(statusPresentation.message)

            if store.snapshot.errorMessage != nil {
                AppErrorBanner(snapshot: store.snapshot)
            }

            Divider()

            HStack {
                Button {
                    Task {
                        await store.refresh()
                    }
                } label: {
                    Label(store.isRefreshing ? "Refreshing" : "Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isRefreshing)
                .accessibilityLabel(store.isRefreshing ? "Refreshing Codex limits" : "Refresh Codex limits")
                .accessibilityValue(store.isRefreshing ? "Update in progress" : "Ready")

                Spacer()

                Button("Open") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }

                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 360)
    }

    private var statusPresentation: AppStatusPresentation {
        AppStatusPresentation(snapshot: store.snapshot)
    }

    private func menuWindowRow(_ window: LimitWindowSnapshot) -> some View {
        HStack {
            Image(systemName: iconName(for: window.kind))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(window.title)
                .lineLimit(2)
            Spacer()
            Text(remainingText(window.remainingPercent))
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.callout)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(window.title) usage window")
        .accessibilityValue(windowAccessibilityValue(window))
    }

    private func remainingText(_ value: Int?) -> String {
        value.map { "\($0)% remaining" } ?? "— remaining"
    }

    private func iconName(for kind: LimitWindowKind) -> String {
        switch kind {
        case .fiveHour:
            return "clock"
        case .weekly:
            return "calendar"
        case .generic:
            return "gauge"
        }
    }

    private func windowAccessibilityValue(_ window: LimitWindowSnapshot) -> String {
        let remaining = window.remainingPercent.map { "\($0)% remaining" } ?? "remaining unavailable"
        let used = window.usedPercent.map { "\($0)% used" } ?? "used unavailable"
        let reset: String
        if let resetDate = window.resetDate {
            reset = "resets \(CodexLimitDateFormatting.resetTime(resetDate))"
        } else if let resetAfterSeconds = window.resetAfterSeconds {
            reset = "resets in \(CodexLimitDateFormatting.duration(seconds: resetAfterSeconds))"
        } else {
            reset = "reset unavailable"
        }
        return "\(remaining), \(used), \(reset)"
    }
}
