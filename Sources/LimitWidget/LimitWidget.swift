import CodexLimitCore
import SwiftUI
import WidgetKit

struct LimitWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: LimitSnapshot
}

struct LimitWidgetProvider: TimelineProvider {
    private let snapshotStore = CodexLimitSnapshotStore()

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
                small
            case .systemLarge:
                large
            default:
                medium
            }
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "codex-limit-widget://open"))
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Codex")
                    .font(.headline)
                Spacer()
                Text("\(entry.snapshot.availableResetCount)R")
                    .font(.headline)
                    .monospacedDigit()
            }

            Text(entry.snapshot.statusTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 3) {
                meterLine(label: "5h", value: entry.snapshot.fiveHourWindow?.remainingPercent)
                meterLine(label: "W", value: entry.snapshot.weeklyWindow?.remainingPercent)
            }
        }
        .padding()
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Codex Limit Widget")
                        .font(.headline)
                    Text(CodexLimitDateFormatting.checked(entry.snapshot.checkedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(entry.snapshot.availableResetCount)R")
                    .font(.title2.bold())
                    .monospacedDigit()
            }

            HStack(spacing: 10) {
                widgetMeter(title: "5h", window: entry.snapshot.fiveHourWindow)
                widgetMeter(title: "Weekly", window: entry.snapshot.weeklyWindow)
            }

            Text(entry.snapshot.statusTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding()
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Codex Limit Widget")
                        .font(.headline)
                    Text(CodexLimitDateFormatting.checked(entry.snapshot.checkedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(entry.snapshot.availableResetCount)R")
                    .font(.title.bold())
                    .monospacedDigit()
            }

            if entry.snapshot.windows.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.snapshot.statusTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(widgetMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            } else {
                ForEach(entry.snapshot.windows) { window in
                    largeWindowRow(window)
                }
                Spacer(minLength: 0)
                Text(widgetMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
    }

    private func widgetMeter(title: String, window: LimitWindowSnapshot?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(percentText(window?.remainingPercent))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
            ProgressView(value: Double(window?.remainingPercent ?? 0), total: 100)
                .tint(tint(for: window?.remainingPercent))
            Text(CodexLimitDateFormatting.duration(seconds: window?.resetAfterSeconds))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func largeWindowRow(_ window: LimitWindowSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(window.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(percentText(window.remainingPercent))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
            }
            ProgressView(value: Double(window.remainingPercent ?? 0), total: 100)
                .tint(tint(for: window.remainingPercent))
            HStack {
                Text("\(percentText(window.usedPercent)) used")
                Spacer()
                Text("Resets \(CodexLimitDateFormatting.duration(seconds: window.resetAfterSeconds))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var widgetMessage: String {
        if let message = entry.snapshot.errorMessage {
            return message
        }
        if entry.snapshot.isNotChecked {
            return "Open the app or wait for the first refresh."
        }
        return entry.snapshot.statusTitle
    }

    private func meterLine(label: String, value: Int?) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(percentText(value))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
    }

    private func percentText(_ value: Int?) -> String {
        guard let value else {
            return "-"
        }
        return "\(value)%"
    }

    private func tint(for remaining: Int?) -> Color {
        guard let remaining else {
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
}

@main
struct LimitWidget: Widget {
    let kind = "LimitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LimitWidgetProvider()) { entry in
            LimitWidgetView(entry: entry)
        }
        .configurationDisplayName("Codex Limit Widget")
        .description("Shows Codex 5h, weekly, and reset-bank status.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
