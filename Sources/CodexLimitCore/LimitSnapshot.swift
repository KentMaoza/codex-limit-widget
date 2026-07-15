import Foundation

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
}
