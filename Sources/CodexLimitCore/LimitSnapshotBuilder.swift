import Foundation

public enum LimitSnapshotBuilder {
    public static func make(
        usage: CodexUsageResponse?,
        resetCredits: ResetCreditsResponse?,
        now: Date = Date(),
        errorMessage: String? = nil
    ) -> LimitSnapshot {
        let windows = usage?.rateLimit.map { rateLimit in
            buildWindows(from: rateLimit)
        } ?? []

        let resetCount = resetCredits?.availableCount
            ?? usage?.rateLimitResetCredits?.availableCount
            ?? 0

        return LimitSnapshot(
            generatedAt: now,
            planLabel: planLabel(from: usage?.planType),
            availableResetCount: resetCount,
            windows: windows,
            errorMessage: errorMessage
        )
    }

    private static func buildWindows(from rateLimit: CodexRateLimit) -> [LimitWindowSnapshot] {
        var windows: [LimitWindowSnapshot] = []
        if let primary = rateLimit.primaryWindow {
            windows.append(display(for: primary, fallbackID: "primary"))
        }
        if let secondary = rateLimit.secondaryWindow {
            windows.append(display(for: secondary, fallbackID: "secondary"))
        }
        return windows
    }

    private static func display(for window: UsageLimitWindow, fallbackID: String) -> LimitWindowSnapshot {
        let seconds = window.limitWindowSeconds ?? 0
        if fallbackID == "primary" || (14_400...21_600).contains(seconds) {
            return snapshot(id: "five-hour", kind: .fiveHour, title: "5h limit", window: window)
        }
        if fallbackID == "secondary" || (518_400...864_000).contains(seconds) {
            return snapshot(id: "weekly", kind: .weekly, title: "Weekly limit", window: window)
        }
        return snapshot(id: fallbackID, kind: .generic, title: windowTitle(seconds: seconds), window: window)
    }

    private static func snapshot(
        id: String,
        kind: LimitWindowKind,
        title: String,
        window: UsageLimitWindow
    ) -> LimitWindowSnapshot {
        LimitWindowSnapshot(
            id: id,
            kind: kind,
            title: title,
            usedPercent: window.usedPercent.map { max(0, min(100, $0)) },
            remainingPercent: window.remainingPercent,
            resetAfterSeconds: window.resetAfterSeconds,
            resetAt: window.resetAt
        )
    }

    private static func planLabel(from planType: String?) -> String {
        guard let planType, !planType.isEmpty else {
            return "Codex"
        }
        return planType
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private static func windowTitle(seconds: Int) -> String {
        if seconds >= 86_400 {
            let days = max(1, seconds / 86_400)
            return "\(days)d limit"
        }
        let hours = max(1, seconds / 3_600)
        return "\(hours)h limit"
    }
}
