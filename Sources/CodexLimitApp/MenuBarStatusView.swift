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
                    .foregroundStyle(statusPresentation.tint)
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
        let presentation = LimitWindowPresentation(window: window)

        return HStack {
            Image(systemName: presentation.iconName)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(window.title)
                .lineLimit(2)
            Spacer()
            Text(presentation.menuRemainingText)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.callout)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(window.title) usage window")
        .accessibilityValue(presentation.accessibilityValue)
    }
}
