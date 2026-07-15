import Foundation

public enum LimitSnapshotBuilder {
    public static func make(
        usage: CodexUsageResponse?,
        resetCredits: ResetCreditsResponse?,
        now: Date = Date(),
        errorMessage: String? = nil,
        settings: CodexSettings = CodexSettings()
    ) -> LimitSnapshot {
        var windows = usage?.rateLimit.map { buildWindows(from: $0) } ?? []
        for (index, additionalLimit) in (usage?.additionalRateLimits ?? []).enumerated() {
            windows.append(contentsOf: buildWindows(
                from: additionalLimit.rateLimit,
                idPrefix: "additional-\(index)",
                titlePrefix: additionalLimit.limitName
            ))
        }

        let resetCount = resetCredits?.availableCount
            ?? usage?.rateLimitResetCredits?.availableCount
            ?? 0

        return LimitSnapshot(
            generatedAt: now,
            planLabel: planLabel(from: usage?.planType),
            availableResetCount: resetCount,
            creditBalance: usage?.credits?.balance,
            activeModel: settings.model,
            reasoningEffort: settings.reasoningEffort,
            windows: windows,
            errorMessage: errorMessage
        )
    }

    private static func buildWindows(
        from rateLimit: CodexRateLimit,
        idPrefix: String? = nil,
        titlePrefix: String? = nil
    ) -> [LimitWindowSnapshot] {
        var windows: [LimitWindowSnapshot] = []
        if let primary = rateLimit.primaryWindow {
            windows.append(display(
                for: primary,
                fallbackID: "primary",
                idPrefix: idPrefix,
                titlePrefix: titlePrefix
            ))
        }
        if let secondary = rateLimit.secondaryWindow {
            windows.append(display(
                for: secondary,
                fallbackID: "secondary",
                idPrefix: idPrefix,
                titlePrefix: titlePrefix
            ))
        }
        return windows
    }

    private static func display(
        for window: UsageLimitWindow,
        fallbackID: String,
        idPrefix: String?,
        titlePrefix: String?
    ) -> LimitWindowSnapshot {
        if let seconds = window.limitWindowSeconds {
            if (14_400...21_600).contains(seconds) {
                return snapshot(
                    id: prefixed("five-hour", with: idPrefix),
                    kind: .fiveHour,
                    title: titled("5h", fallback: "5h limit", prefix: titlePrefix),
                    window: window
                )
            }
            if (518_400...864_000).contains(seconds) {
                return snapshot(
                    id: prefixed("weekly", with: idPrefix),
                    kind: .weekly,
                    title: titled("Weekly", fallback: "Weekly limit", prefix: titlePrefix),
                    window: window
                )
            }
            let fallbackTitle = windowTitle(seconds: seconds)
            return snapshot(
                id: prefixed(fallbackID, with: idPrefix),
                kind: .generic,
                title: titled(fallbackTitle, fallback: fallbackTitle, prefix: titlePrefix),
                window: window
            )
        }
        if fallbackID == "primary" {
            return snapshot(
                id: prefixed("five-hour", with: idPrefix),
                kind: .fiveHour,
                title: titled("5h", fallback: "5h limit", prefix: titlePrefix),
                window: window
            )
        }
        if fallbackID == "secondary" {
            return snapshot(
                id: prefixed("weekly", with: idPrefix),
                kind: .weekly,
                title: titled("Weekly", fallback: "Weekly limit", prefix: titlePrefix),
                window: window
            )
        }
        let fallbackTitle = "Limit"
        return snapshot(
            id: prefixed(fallbackID, with: idPrefix),
            kind: .generic,
            title: titled(fallbackTitle, fallback: fallbackTitle, prefix: titlePrefix),
            window: window
        )
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
        if planType.caseInsensitiveCompare("prolite") == .orderedSame {
            return "Pro Lite"
        }
        if planType.caseInsensitiveCompare("chatgpt_pro") == .orderedSame {
            return "ChatGPT Pro"
        }
        return planType
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private static func prefixed(_ value: String, with prefix: String?) -> String {
        prefix.map { "\($0)-\(value)" } ?? value
    }

    private static func titled(_ value: String, fallback: String, prefix: String?) -> String {
        prefix.map { "\($0) · \(value)" } ?? fallback
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
