import Foundation

public enum LimitStatusLevel: Sendable, Equatable {
    case unavailable
    case error
    case critical
    case warning
    case normal
}

public extension LimitSnapshot {
    var hasData: Bool {
        generatedAt.timeIntervalSince1970 > 0
    }

    var isStale: Bool {
        hasData && errorMessage != nil
    }

    var statusLevel: LimitStatusLevel {
        if errorMessage != nil {
            return .error
        }
        guard hasData else {
            return .unavailable
        }
        let remainingPercentages = windows.compactMap(\.remainingPercent)
        if remainingPercentages.contains(where: { $0 <= 15 }) {
            return .critical
        }
        if remainingPercentages.contains(where: { $0 <= 30 }) {
            return .warning
        }
        return .normal
    }

    var isNotChecked: Bool {
        generatedAt.timeIntervalSince1970 == 0 && windows.isEmpty && errorMessage == nil
    }

    var checkedAt: Date? {
        hasData ? generatedAt : nil
    }

    var configurationLine: String? {
        [activeModel, reasoningEffort]
            .compactMap { value in
                guard let value, !value.isEmpty else {
                    return nil
                }
                return value
            }
            .joined(separator: " · ")
            .nilIfEmpty
    }

    var balanceValue: String {
        if let creditBalance {
            return creditBalance
        }
        return isResetCountAvailable ? "\(availableResetCount)" : "—"
    }

    var balanceCaption: String {
        if creditBalance != nil {
            return "credit balance"
        }
        return availableResetCount == 1 ? "reset banked" : "resets banked"
    }

    var compactBalance: String {
        if let creditBalance {
            return "\(creditBalance) cr"
        }
        return isResetCountAvailable ? "\(availableResetCount)R" : "—"
    }

    var fiveHourWindow: LimitWindowSnapshot? {
        windows.first { $0.id == "five-hour" }
    }

    var weeklyWindow: LimitWindowSnapshot? {
        windows.first { $0.id == "weekly" }
    }

    var summaryLine: String {
        if isNotChecked {
            return "Not checked yet"
        }
        let fiveHour = percentText(fiveHourWindow?.remainingPercent)
        let weekly = percentText(weeklyWindow?.remainingPercent)
        return "5h \(fiveHour) / W \(weekly) / \(compactBalance)"
    }

    var statusTitle: String {
        switch statusLevel {
        case .unavailable:
            return "Not checked yet"
        case .error:
            return "Check Codex login"
        case .critical, .warning:
            if let weekly = weeklyWindow?.remainingPercent, weekly <= 30 {
                return availableResetCount > 0 ? "Reset ready if blocked" : "Weekly limit is low"
            }
            if let fiveHour = fiveHourWindow?.remainingPercent, fiveHour <= 30 {
                return "Short window is low"
            }
            return statusLevel == .critical ? "Capacity is critically low" : "Capacity is low"
        case .normal:
            return availableResetCount > 0 ? "Reset banked" : "Capacity available"
        }
    }

    private func percentText(_ value: Int?) -> String {
        value.map { "\($0)%" } ?? "—"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
