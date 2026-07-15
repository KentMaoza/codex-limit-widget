import CodexLimitCore
import SwiftUI
import WidgetKit

struct LimitWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: LimitSnapshot
}

struct LimitWidgetProvider: TimelineProvider {
    private let snapshotStore = CodexLimitSnapshotStore.runtimeDefault

    func placeholder(in context: Context) -> LimitWidgetEntry {
        LimitWidgetEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (LimitWidgetEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LimitWidgetEntry>) -> Void) {
        let currentEntry = entry()
        let refreshDate = Date().addingTimeInterval(CodexLimitRefreshPolicy.refreshInterval)
        completion(Timeline(entries: [currentEntry], policy: .after(refreshDate)))
    }

    private func entry() -> LimitWidgetEntry {
        LimitWidgetEntry(date: Date(), snapshot: snapshotStore.load() ?? .notChecked)
    }
}

struct LimitWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LimitWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallLimitWidgetView(snapshot: entry.snapshot)
            case .systemLarge:
                LargeLimitWidgetView(snapshot: entry.snapshot)
            default:
                MediumLimitWidgetView(snapshot: entry.snapshot)
            }
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "codex-limit-widget://open"))
    }
}

@main
struct LimitWidget: Widget {
    let kind = "LimitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LimitWidgetProvider()) { entry in
            LimitWidgetView(entry: entry)
        }
        .configurationDisplayName("Codex Limit Widget")
        .description("Shows Codex usage, credits, and the current model configuration.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
