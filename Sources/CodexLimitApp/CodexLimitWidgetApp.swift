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
                .frame(minWidth: 560, idealWidth: 680, minHeight: 640, idealHeight: 700)
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
                .disabled(store.isRefreshing)
            }
        }

        MenuBarExtra {
            MenuBarStatusView(store: store)
                .task {
                    store.start()
                }
        } label: {
            let presentation = AppStatusPresentation(snapshot: store.snapshot)
            Label {
                Text(store.snapshot.summaryLine)
            } icon: {
                Image(systemName: store.statusSymbolName)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.title)
            .accessibilityValue(presentation.menuBarAccessibilityValue)
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
        snapshotStore: CodexLimitSnapshotStore = .runtimeDefault
    ) {
        self.service = service
        self.snapshotStore = snapshotStore
        self.snapshot = snapshotStore.load() ?? .notChecked
    }

    var statusSymbolName: String {
        AppStatusPresentation(snapshot: snapshot).symbolName
    }

    func start() {
        guard refreshTask == nil else {
            return
        }

        refreshTask = Task { [weak self] in
            guard let self else {
                return
            }

            let clock = ContinuousClock()
            while !Task.isCancelled {
                let startedAt = clock.now
                let result = await self.performRefresh()
                let duration = startedAt.duration(to: clock.now).components
                let elapsed = TimeInterval(duration.seconds)
                    + TimeInterval(duration.attoseconds) / 1_000_000_000_000_000_000
                let delay = CodexLimitRefreshPolicy.delayUntilNextStart(
                    elapsed: elapsed,
                    retryAfterDelay: result?.retryAfterDelay
                )
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    return
                }
            }
        }
    }

    func refresh() async {
        _ = await performRefresh()
    }

    private func performRefresh() async -> LimitRefreshResult? {
        guard !isRefreshing else {
            return nil
        }

        isRefreshing = true
        defer {
            isRefreshing = false
        }

        let result: LimitRefreshResult
        do {
            result = try await service.refresh(previous: snapshot)
            try Task.checkCancellation()
        } catch is CancellationError {
            return nil
        } catch {
            return nil
        }

        do {
            try snapshotStore.save(result.snapshot)
        } catch {
            guard !Task.isCancelled else {
                return result
            }
            let saveMessage = "Could not save widget snapshot: \(error.localizedDescription)"
            snapshot = LimitSnapshot(
                generatedAt: result.snapshot.generatedAt,
                lastAttemptAt: result.snapshot.lastAttemptAt,
                planLabel: result.snapshot.planLabel,
                availableResetCount: result.snapshot.availableResetCount,
                creditBalance: result.snapshot.creditBalance,
                activeModel: result.snapshot.activeModel,
                reasoningEffort: result.snapshot.reasoningEffort,
                windows: result.snapshot.windows,
                errorMessage: [result.snapshot.errorMessage, saveMessage]
                    .compactMap { $0 }
                    .joined(separator: " ")
            )
            return result
        }

        guard !Task.isCancelled else {
            return result
        }
        WidgetCenter.shared.reloadAllTimelines()
        snapshot = result.snapshot
        return result
    }
}
