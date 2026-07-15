import Foundation

public enum CodexLimitRefreshPolicy {
    public static let refreshIntervalSeconds: Int = 60
    public static let refreshInterval: TimeInterval = TimeInterval(refreshIntervalSeconds)

    public static func delayUntilNextStart(
        elapsed: TimeInterval,
        retryAfterDelay: TimeInterval?
    ) -> TimeInterval {
        let nominalDelay = max(0, refreshInterval - elapsed)
        return max(nominalDelay, retryAfterDelay ?? 0)
    }
}
