import Foundation

public struct LimitRefreshResult: Equatable, Sendable {
    public let snapshot: LimitSnapshot
    public let nextAllowedRefreshDelay: TimeInterval
}

public struct CodexLimitService: Sendable {
    private let client: CodexLimitClient

    public init(client: CodexLimitClient = CodexLimitClient()) {
        self.client = client
    }

    public func refresh(previous: LimitSnapshot?, now: Date = Date()) async throws -> LimitRefreshResult {
        async let usageOutcome = Self.fetchOutcome {
            try await client.fetchUsage()
        }
        async let resetOutcome = Self.fetchOutcome {
            try await client.fetchResetCredits()
        }

        let (usage, resetCredits) = try await (usageOutcome, resetOutcome)
        try Task.checkCancellation()

        let failures = [usage.failure, resetCredits.failure].compactMap { $0 }
        let nextDelay = failures
            .compactMap(\.retryAfter)
            .reduce(CodexLimitRefreshPolicy.refreshInterval, max)

        let snapshot: LimitSnapshot
        switch usage {
        case let .success(response):
            let resetResponse = resetCredits.value
            let hasUsageCreditFallback = response.rateLimitResetCredits?.availableCount != nil
                || response.credits?.balance != nil
            let partialError = hasUsageCreditFallback ? nil : resetCredits.failure?.message
            snapshot = LimitSnapshotBuilder.make(
                usage: response,
                resetCredits: resetResponse,
                now: now,
                errorMessage: partialError,
                settings: client.loadSettings()
            )
        case .failure:
            snapshot = Self.retainingPrevious(
                previous,
                lastAttemptAt: now,
                errorMessage: Self.deduplicatedMessage(failures.map(\.message))
            )
        }

        return LimitRefreshResult(snapshot: snapshot, nextAllowedRefreshDelay: nextDelay)
    }

    private static func fetchOutcome<Value: Sendable>(
        _ operation: @Sendable () async throws -> Value
    ) async throws -> FetchOutcome<Value> {
        do {
            return .success(try await operation())
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            return .failure(RefreshFailure(
                message: error.localizedDescription,
                retryAfter: (error as? CodexLimitError)?.retryAfterSeconds
            ))
        }
    }

    private static func retainingPrevious(
        _ previous: LimitSnapshot?,
        lastAttemptAt: Date,
        errorMessage: String?
    ) -> LimitSnapshot {
        let source = previous ?? .notChecked
        return LimitSnapshot(
            generatedAt: source.generatedAt,
            lastAttemptAt: lastAttemptAt,
            planLabel: source.planLabel,
            availableResetCount: source.availableResetCount,
            isResetCountAvailable: source.isResetCountAvailable,
            creditBalance: source.creditBalance,
            activeModel: source.activeModel,
            reasoningEffort: source.reasoningEffort,
            windows: source.windows,
            errorMessage: errorMessage
        )
    }

    private static func deduplicatedMessage(_ messages: [String]) -> String? {
        var uniqueMessages: [String] = []
        for message in messages where !uniqueMessages.contains(message) {
            uniqueMessages.append(message)
        }
        return uniqueMessages.isEmpty ? nil : uniqueMessages.joined(separator: " ")
    }
}

private struct RefreshFailure: Sendable {
    let message: String
    let retryAfter: TimeInterval?
}

private enum FetchOutcome<Value: Sendable>: Sendable {
    case success(Value)
    case failure(RefreshFailure)

    var value: Value? {
        guard case let .success(value) = self else {
            return nil
        }
        return value
    }

    var failure: RefreshFailure? {
        guard case let .failure(failure) = self else {
            return nil
        }
        return failure
    }
}

private extension CodexLimitError {
    var retryAfterSeconds: TimeInterval? {
        guard case let .rateLimited(delay) = self else {
            return nil
        }
        return delay
    }
}
