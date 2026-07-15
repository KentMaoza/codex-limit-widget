import Foundation

public struct CodexUsageResponse: Decodable, Sendable {
    public let planType: String?
    public let rateLimit: CodexRateLimit?
    public let additionalRateLimits: [AdditionalRateLimit]?
    public let rateLimitResetCredits: ResetCreditCount?
    public let credits: UsageCredits?
}

public struct AdditionalRateLimit: Decodable, Sendable {
    public let limitName: String
    public let meteredFeature: String?
    public let rateLimit: CodexRateLimit
}

public struct UsageCredits: Decodable, Sendable {
    public let balance: String?

    private enum CodingKeys: String, CodingKey {
        case balance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        balance = try container.decodeFlexibleStringIfPresent(forKey: .balance)
    }
}

public struct CodexRateLimit: Decodable, Sendable {
    public let allowed: Bool?
    public let limitReached: Bool?
    public let primaryWindow: UsageLimitWindow?
    public let secondaryWindow: UsageLimitWindow?
}

public struct UsageLimitWindow: Decodable, Sendable {
    public let usedPercent: Int?
    public let limitWindowSeconds: Int?
    public let resetAfterSeconds: Int?
    public let resetAt: TimeInterval?

    public var remainingPercent: Int? {
        guard let usedPercent else {
            return nil
        }
        return max(0, min(100, 100 - usedPercent))
    }

    public var resetDate: Date? {
        guard let resetAt else {
            return nil
        }
        let seconds = resetAt > 10_000_000_000 ? resetAt / 1_000 : resetAt
        return Date(timeIntervalSince1970: seconds)
    }
}

public struct ResetCreditCount: Decodable, Sendable {
    public let availableCount: Int?
}

public struct ResetCreditsResponse: Decodable, Sendable {
    public let credits: [ResetCredit]
    public let availableCount: Int

    private enum CodingKeys: String, CodingKey {
        case credits
        case availableCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        credits = (try container.decodeIfPresent([FailableDecodable<ResetCredit>].self, forKey: .credits) ?? [])
            .compactMap(\.value)
        availableCount = try container.decodeIfPresent(Int.self, forKey: .availableCount)
            ?? credits.filter(\.isAvailable).count
    }
}

public struct ResetCredit: Decodable, Identifiable, Sendable {
    public let id: String
    public let resetType: String
    public let status: String
    public let expiresAt: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case resetType
        case status
        case expiresAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        resetType = try container.decodeFlexibleStringIfPresent(forKey: .resetType) ?? "unknown"
        status = try container.decodeFlexibleStringIfPresent(forKey: .status) ?? "unknown"
        expiresAt = try container.decodeFlexibleStringIfPresent(forKey: .expiresAt)
    }

    public var isAvailable: Bool {
        status.caseInsensitiveCompare("available") == .orderedSame
    }
}

public enum LimitWindowKind: String, Codable, Sendable {
    case fiveHour
    case weekly
    case generic
}

public struct LimitWindowSnapshot: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let kind: LimitWindowKind
    public let title: String
    public let usedPercent: Int?
    public let remainingPercent: Int?
    public let resetAfterSeconds: Int?
    public let resetAt: TimeInterval?

    public init(
        id: String,
        kind: LimitWindowKind,
        title: String,
        usedPercent: Int?,
        remainingPercent: Int?,
        resetAfterSeconds: Int?,
        resetAt: TimeInterval?
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.usedPercent = usedPercent
        self.remainingPercent = remainingPercent
        self.resetAfterSeconds = resetAfterSeconds
        self.resetAt = resetAt
    }

    public var resetDate: Date? {
        guard let resetAt else {
            return nil
        }
        let seconds = resetAt > 10_000_000_000 ? resetAt / 1_000 : resetAt
        return Date(timeIntervalSince1970: seconds)
    }
}

public struct LimitSnapshot: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let lastAttemptAt: Date?
    public let planLabel: String
    public let availableResetCount: Int
    public let creditBalance: String?
    public let activeModel: String?
    public let reasoningEffort: String?
    public let windows: [LimitWindowSnapshot]
    public let errorMessage: String?

    public init(
        generatedAt: Date,
        lastAttemptAt: Date? = nil,
        planLabel: String,
        availableResetCount: Int,
        creditBalance: String? = nil,
        activeModel: String? = nil,
        reasoningEffort: String? = nil,
        windows: [LimitWindowSnapshot],
        errorMessage: String?
    ) {
        self.generatedAt = generatedAt
        self.lastAttemptAt = lastAttemptAt
        self.planLabel = planLabel
        self.availableResetCount = availableResetCount
        self.creditBalance = creditBalance
        self.activeModel = activeModel
        self.reasoningEffort = reasoningEffort
        self.windows = windows
        self.errorMessage = errorMessage
    }

    private enum CodingKeys: String, CodingKey {
        case generatedAt
        case lastAttemptAt
        case planLabel
        case availableResetCount
        case creditBalance
        case activeModel
        case reasoningEffort
        case windows
        case errorMessage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        lastAttemptAt = try container.decodeIfPresent(Date.self, forKey: .lastAttemptAt)
        planLabel = try container.decode(String.self, forKey: .planLabel)
        availableResetCount = try container.decode(Int.self, forKey: .availableResetCount)
        creditBalance = try container.decodeIfPresent(String.self, forKey: .creditBalance)
        activeModel = try container.decodeIfPresent(String.self, forKey: .activeModel)
        reasoningEffort = try container.decodeIfPresent(String.self, forKey: .reasoningEffort)
        windows = try container.decode([LimitWindowSnapshot].self, forKey: .windows)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
    }

    public static let placeholder = LimitSnapshot(
        generatedAt: Date(),
        planLabel: "Codex",
        availableResetCount: 0,
        windows: [
            LimitWindowSnapshot(
                id: "five-hour",
                kind: .fiveHour,
                title: "5h limit",
                usedPercent: 0,
                remainingPercent: 100,
                resetAfterSeconds: 60 * 60,
                resetAt: nil
            ),
            LimitWindowSnapshot(
                id: "weekly",
                kind: .weekly,
                title: "Weekly limit",
                usedPercent: 0,
                remainingPercent: 100,
                resetAfterSeconds: 24 * 60 * 60,
                resetAt: nil
            )
        ],
        errorMessage: nil
    )

    public static let notChecked = LimitSnapshot(
        generatedAt: Date(timeIntervalSince1970: 0),
        planLabel: "Codex",
        availableResetCount: 0,
        windows: [],
        errorMessage: nil
    )

    public var isNotChecked: Bool {
        generatedAt.timeIntervalSince1970 == 0 && windows.isEmpty && errorMessage == nil
    }

    public var checkedAt: Date? {
        generatedAt.timeIntervalSince1970 > 0 ? generatedAt : nil
    }

    public var configurationLine: String? {
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

    public var balanceValue: String {
        creditBalance ?? "\(availableResetCount)"
    }

    public var balanceCaption: String {
        if creditBalance != nil {
            return "credit balance"
        }
        return availableResetCount == 1 ? "reset banked" : "resets banked"
    }

    public var compactBalance: String {
        creditBalance.map { "\($0) cr" } ?? "\(availableResetCount)R"
    }

    public var fiveHourWindow: LimitWindowSnapshot? {
        windows.first { $0.id == "five-hour" }
    }

    public var weeklyWindow: LimitWindowSnapshot? {
        windows.first { $0.id == "weekly" }
    }

    public var summaryLine: String {
        if isNotChecked {
            return "Not checked yet"
        }
        let fiveHour = percentText(fiveHourWindow?.remainingPercent)
        let weekly = percentText(weeklyWindow?.remainingPercent)
        let balance = creditBalance.map { "\($0) cr" } ?? "\(availableResetCount)R"
        return "5h \(fiveHour) / W \(weekly) / \(balance)"
    }

    public var statusTitle: String {
        if isNotChecked {
            return "Not checked yet"
        }
        if errorMessage != nil, windows.isEmpty {
            return "Check Codex login"
        }
        if let weekly = weeklyWindow?.remainingPercent, weekly <= 20 {
            return availableResetCount > 0 ? "Reset ready if blocked" : "Weekly limit is low"
        }
        if let fiveHour = fiveHourWindow?.remainingPercent, fiveHour <= 12 {
            return "Short window is low"
        }
        if availableResetCount > 0 {
            return "Reset banked"
        }
        return "Capacity available"
    }

    private func percentText(_ value: Int?) -> String {
        guard let value else {
            return "-"
        }
        return "\(value)%"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private struct FailableDecodable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) throws -> String {
        if let value = try decodeFlexibleStringIfPresent(forKey: key) {
            return value
        }
        throw DecodingError.keyNotFound(
            key,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Missing required string for \(key.stringValue)")
        )
    }

    func decodeFlexibleStringIfPresent(forKey key: Key) throws -> String? {
        guard contains(key) else {
            return nil
        }
        if try decodeNil(forKey: key) {
            return nil
        }
        if let value = try? decode(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        return nil
    }
}
