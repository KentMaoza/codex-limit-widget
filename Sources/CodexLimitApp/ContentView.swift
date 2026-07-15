import CodexLimitCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: LimitStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppHeaderView(snapshot: store.snapshot)

            if store.snapshot.errorMessage != nil {
                AppErrorBanner(snapshot: store.snapshot)
            }

            ScrollView {
                if store.snapshot.windows.isEmpty {
                    VStack(spacing: 6) {
                        Text("No usage windows available")
                            .font(.headline)
                        Text("Refresh to check for current limit windows.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .accessibilityElement(children: .combine)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(store.snapshot.windows) { window in
                            LimitWindowCard(window: window)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .accessibilityLabel("Usage windows")

            AppStatusCard(snapshot: store.snapshot)

            Spacer(minLength: 0)

            footer
        }
        .padding(18)
        .background(Color(nsColor: .windowBackgroundColor))
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
            .accessibilityLabel(store.isRefreshing ? "Refreshing Codex limits" : "Refresh Codex limits")
            .accessibilityValue(store.isRefreshing ? "Update in progress" : "Ready")
        }
    }

}
