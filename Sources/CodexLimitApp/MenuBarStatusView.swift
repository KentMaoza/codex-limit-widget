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
                    Text(CodexLimitDateFormatting.checked(store.snapshot.checkedAt))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            ForEach(store.snapshot.windows) { window in
                HStack {
                    Image(systemName: window.kind == .weekly ? "calendar" : "clock")
                        .foregroundStyle(.secondary)
                    Text(window.title)
                    Spacer()
                    Text(remainingText(window.remainingPercent))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .font(.callout)
            }

            HStack {
                Image(systemName: store.statusSymbolName)
                    .foregroundStyle(.secondary)
                Text(store.snapshot.statusTitle)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer()
            }

            if let message = store.snapshot.errorMessage {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }

            Divider()

            HStack {
                Button {
                    Task {
                        await store.refresh()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isRefreshing)

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
        .frame(width: 330)
    }

    private func remainingText(_ value: Int?) -> String {
        guard let value else {
            return "Unknown"
        }
        return "\(value)% left"
    }
}
