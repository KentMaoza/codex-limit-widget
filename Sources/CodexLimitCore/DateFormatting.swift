import Foundation

public enum CodexLimitDateFormatting {
    public static func parse(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }

        let fractionalParser = ISO8601DateFormatter()
        fractionalParser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalParser.date(from: value) {
            return date
        }

        let standardParser = ISO8601DateFormatter()
        standardParser.formatOptions = [.withInternetDateTime]
        return standardParser.date(from: value)
    }

    public static func checked(_ date: Date?) -> String {
        guard let date else {
            return "Not checked yet"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.timeZone = .current
        return "Last checked \(formatter.string(from: date))"
    }

    public static func duration(seconds: Int?) -> String {
        guard let seconds else {
            return "-"
        }

        let clamped = max(0, seconds)
        if clamped == 0 {
            return "now"
        }

        let days = clamped / 86_400
        let hours = (clamped % 86_400) / 3_600
        let minutes = (clamped % 3_600) / 60

        if days > 0 {
            return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(max(1, minutes))m"
    }

    public static func resetTime(_ date: Date?) -> String {
        guard let date else {
            return "-"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
