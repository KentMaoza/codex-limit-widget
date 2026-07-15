import CodexLimitCore
import SwiftUI

struct WidgetStatusPresentation {
    let snapshot: LimitSnapshot

    var symbolName: String {
        switch snapshot.statusLevel {
        case .unavailable:
            return "clock"
        case .error:
            return "exclamationmark.triangle"
        case .critical:
            return "exclamationmark.octagon"
        case .warning:
            return "exclamationmark.triangle"
        case .normal:
            return "gauge"
        }
    }

    var tint: Color {
        switch snapshot.statusLevel {
        case .unavailable:
            return .secondary
        case .error, .warning:
            return .orange
        case .critical:
            return .red
        case .normal:
            return .teal
        }
    }

    var title: String {
        switch snapshot.statusLevel {
        case .unavailable:
            return "Not checked yet"
        case .error:
            return "Update failed"
        case .critical:
            return "Critical: capacity is low"
        case .warning:
            return "Warning: capacity is low"
        case .normal:
            return snapshot.statusTitle
        }
    }

    var context: String {
        switch snapshot.statusLevel {
        case .unavailable:
            return "Waiting for first update"
        case .error where snapshot.isStale:
            return "Saved data remains visible"
        case .error:
            return "No saved data yet"
        case .critical, .warning, .normal:
            return CodexLimitDateFormatting.checked(snapshot.checkedAt)
        }
    }

    var accessibilityValue: String {
        var parts = [context]
        if snapshot.isStale {
            parts.append(CodexLimitDateFormatting.checked(snapshot.checkedAt))
        }
        if let errorMessage = snapshot.errorMessage {
            parts.append(errorMessage)
        }
        return parts.joined(separator: ". ")
    }
}

struct WidgetMeterPresentation {
    let window: LimitWindowSnapshot?

    var percentText: String {
        window?.remainingPercent.map { "\($0)%" } ?? "—"
    }

    var usedText: String {
        window?.usedPercent.map { "\($0)% used" } ?? "— used"
    }

    var accessibilityValue: String {
        var parts: [String] = []
        if let remaining = window?.remainingPercent {
            parts.append("\(remaining) percent remaining")
        } else {
            parts.append("Remaining percentage unavailable")
        }

        if let used = window?.usedPercent {
            parts.append("\(used) percent used")
        }

        if let resetDate = window?.resetDate {
            parts.append("Resets at \(CodexLimitDateFormatting.resetTime(resetDate))")
        } else if let resetAfterSeconds = window?.resetAfterSeconds {
            parts.append("Resets in \(CodexLimitDateFormatting.duration(seconds: resetAfterSeconds))")
        } else {
            parts.append("Reset time unavailable")
        }
        return parts.joined(separator: ". ")
    }
}
