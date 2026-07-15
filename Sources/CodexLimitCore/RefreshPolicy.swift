import Foundation

public enum CodexLimitRefreshPolicy {
    public static let refreshIntervalSeconds: Int = 60
    public static let refreshInterval: TimeInterval = TimeInterval(refreshIntervalSeconds)

    public static func delayUntilNextStart(
        elapsed: TimeInterval,
        minimumDelay: TimeInterval
    ) -> TimeInterval {
        max(0, minimumDelay - elapsed)
    }
}
