import CodexLimitCore
import SwiftUI

struct WidgetStatusView: View {
    let snapshot: LimitSnapshot
    var showsContext = true
    var showsErrorDetail = false

    private var presentation: WidgetStatusPresentation {
        WidgetStatusPresentation(snapshot: snapshot)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: presentation.symbolName)
                .foregroundStyle(presentation.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                if showsContext {
                    contextText
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if showsErrorDetail, let errorMessage = snapshot.errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.title)
        .accessibilityValue(presentation.accessibilityValue)
    }

    @ViewBuilder
    private var contextText: some View {
        if snapshot.isStale {
            Text("Saved data from ") + Text(snapshot.generatedAt, style: .relative)
        } else {
            Text(presentation.context)
        }
    }
}

struct WidgetHeaderView: View {
    let snapshot: LimitSnapshot
    var large = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Codex Limit Widget")
                    .font(.headline)
                if let configuration = snapshot.configurationLine {
                    Text(configuration)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(snapshot.compactBalance)
                .font(large ? .title.bold() : .title2.bold())
                .monospacedDigit()
                .accessibilityLabel("Balance")
                .accessibilityValue(snapshot.compactBalance == "—" ? "Unavailable" : snapshot.compactBalance)
        }
    }
}

struct WidgetMeter: View {
    let title: String
    let window: LimitWindowSnapshot?
    var showsUsage = false
    var showsReset = false

    private var presentation: WidgetMeterPresentation {
        WidgetMeterPresentation(title: title, window: window)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(presentation.percentText)
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }

            meterBar

            if showsUsage || showsReset {
                HStack {
                    if showsUsage {
                        Text(presentation.usedText)
                    }
                    Spacer()
                    if showsReset {
                        Text("Resets")
                        WidgetResetText(window: window)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) usage window")
        .accessibilityValue(presentation.accessibilityValue)
    }

    @ViewBuilder
    private var meterBar: some View {
        if let remaining = window?.remainingPercent {
            ProgressView(value: Double(remaining), total: 100)
                .progressViewStyle(.linear)
                .tint(tint(for: remaining))
                .accessibilityHidden(true)
        } else {
            Capsule()
                .fill(.secondary.opacity(0.22))
                .frame(height: 4)
                .accessibilityHidden(true)
        }
    }

    private func tint(for remaining: Int) -> Color {
        if remaining <= 15 {
            return .red
        }
        if remaining <= 30 {
            return .orange
        }
        return .green
    }
}

struct WidgetResetText: View {
    let window: LimitWindowSnapshot?

    @ViewBuilder
    var body: some View {
        if let resetDate = window?.resetDate {
            Text(resetDate, style: .relative)
        } else if let resetAfterSeconds = window?.resetAfterSeconds {
            Text(CodexLimitDateFormatting.duration(seconds: resetAfterSeconds))
        } else {
            Text("Unavailable")
        }
    }
}
