import AppKit
import CodexLimitCore
import SwiftUI
import WidgetKit

@main
struct CodexLimitWidgetApp: App {
    @StateObject private var store = LimitStore()

    var body: some Scene {
        WindowGroup("Codex Limit Widget", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 560, idealWidth: 680, minHeight: 420, idealHeight: 560)
                .task {
                    store.start()
                }
                .onOpenURL { _ in
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Codex Limit Widget") {
                Button("Refresh") {
                    Task {
                        await store.refresh()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        MenuBarExtra {
            MenuBarStatusView(store: store)
                .task {
                    store.start()
                }
        } label: {
            Label {
                Text(store.snapshot.summaryLine)
            } icon: {
                Image(systemName: store.statusSymbolName)
            }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class LimitStore: ObservableObject {
    @Published private(set) var snapshot: LimitSnapshot
    @Published private(set) var isRefreshing = false

    private let service: CodexLimitService
    private let snapshotStore: CodexLimitSnapshotStore
    private var refreshTask: Task<Void, Never>?

    init(
        service: CodexLimitService = CodexLimitService(),
        snapshotStore: CodexLimitSnapshotStore = CodexLimitSnapshotStore()
    ) {
        self.service = service
        self.snapshotStore = snapshotStore
        self.snapshot = snapshotStore.load() ?? .notChecked
    }

    var statusSymbolName: String {
        if snapshot.isNotChecked {
            return "clock"
        }
        if snapshot.errorMessage != nil, snapshot.windows.isEmpty {
            return "exclamationmark.triangle"
        }
        if let weekly = snapshot.weeklyWindow?.remainingPercent, weekly <= 20 {
            return "bolt.circle"
        }
        if let fiveHour = snapshot.fiveHourWindow?.remainingPercent, fiveHour <= 12 {
            return "hourglass.circle"
        }
        return "gauge"
    }

    func start() {
        guard refreshTask == nil else {
            return
        }

        refreshTask = Task { [weak self] in
            guard let self else {
                return
            }

            while !Task.isCancelled {
                await self.refresh()
                do {
                    try await Task.sleep(for: .seconds(CodexLimitRefreshPolicy.refreshIntervalSeconds))
                } catch {
                    return
                }
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        defer {
            isRefreshing = false
        }

        var nextSnapshot = await service.loadSnapshot()
        var messages = [nextSnapshot.errorMessage].compactMap { $0 }

        do {
            try snapshotStore.save(nextSnapshot)
        } catch {
            messages.append("Could not save widget snapshot: \(error.localizedDescription)")
        }

        do {
            try CodexLimitSnapshotStore(fileURL: CodexLimitSnapshotStore.localWidgetContainerFileURL()).save(nextSnapshot)
        } catch {
            messages.append("Could not update local widget mirror: \(error.localizedDescription)")
        }

        if !messages.isEmpty {
            nextSnapshot = LimitSnapshot(
                generatedAt: nextSnapshot.generatedAt,
                planLabel: nextSnapshot.planLabel,
                availableResetCount: nextSnapshot.availableResetCount,
                windows: nextSnapshot.windows,
                errorMessage: messages.joined(separator: " ")
            )
        }

        WidgetCenter.shared.reloadAllTimelines()
        snapshot = nextSnapshot
    }
}
