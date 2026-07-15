import Foundation

public struct CodexUsageResponse: Decodable, Sendable {
    public let planType: String?
    public let rateLimit: CodexRateLimit?
    public let additionalRateLimits: [AdditionalRateLimit]?
    public let rateLimitResetCredits: ResetCreditCount?
    public let credits: UsageCredits?

    private enum CodingKeys: String, CodingKey {
        case planType
        case rateLimit
        case additionalRateLimits
        case rateLimitResetCredits
        case credits
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        planType = try container.decodeIfPresent(String.self, forKey: .planType)
        rateLimit = try container.decodeIfPresent(CodexRateLimit.self, forKey: .rateLimit)
        additionalRateLimits = try container
            .decodeIfPresent([FailableDecodable<AdditionalRateLimit>].self, forKey: .additionalRateLimits)?
            .compactMap(\.value)
        rateLimitResetCredits = try container.decodeIfPresent(ResetCreditCount.self, forKey: .rateLimitResetCredits)
        credits = try container.decodeIfPresent(UsageCredits.self, forKey: .credits)
    }
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
