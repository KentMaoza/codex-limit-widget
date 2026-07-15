import CodexLimitCore
import SwiftUI

struct LimitWindowCard: View {
    let window: LimitWindowSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top) {
                HStack(spacing: 6) {
                    Image(systemName: iconName)
                        .accessibilityHidden(true)
                    Text(window.title)
                }
                .font(.headline)
                .lineLimit(2)

                Spacer()

                Text(percentText(window.remainingPercent))
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            remainingMeter

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("Used").foregroundStyle(.secondary)
                    Text(percentText(window.usedPercent)).monospacedDigit()
                }
                GridRow {
                    Text("Resets").foregroundStyle(.secondary)
                    resetRelativeText
                }
                if let resetDate = window.resetDate {
                    GridRow {
                        Text("At").foregroundStyle(.secondary)
                        Text(CodexLimitDateFormatting.resetTime(resetDate))
                    }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(window.title) usage window")
        .accessibilityValue(accessibilityValue)
    }

    @ViewBuilder
    private var remainingMeter: some View {
        if let remainingPercent = window.remainingPercent {
            ProgressView(value: Double(remainingPercent), total: 100)
                .tint(tint(for: remainingPercent))
                .accessibilityHidden(true)
        } else {
            Capsule()
                .fill(.secondary.opacity(0.18))
                .frame(height: 4)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var resetRelativeText: some View {
        if let resetDate = window.resetDate {
            Text(resetDate, style: .relative)
        } else if let resetAfterSeconds = window.resetAfterSeconds {
            Text(CodexLimitDateFormatting.duration(seconds: resetAfterSeconds))
        } else {
            Text("Unavailable")
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

    private var accessibilityValue: String {
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

    private func tint(for remaining: Int) -> Color {
        if remaining <= 15 {
            return .red
        }
        if remaining <= 30 {
            return .orange
        }
        return .green
    }

    private func percentText(_ value: Int?) -> String {
        value.map { "\($0)%" } ?? "—"
    }
}
