import Foundation

public struct CodexLimitService: Sendable {
    private let client: CodexLimitClient

    public init(client: CodexLimitClient = CodexLimitClient()) {
        self.client = client
    }

    public func loadSnapshot(now: Date = Date()) async -> LimitSnapshot {
        var messages: [String] = []
        let usage: CodexUsageResponse?
        let resetCredits: ResetCreditsResponse?

        do {
            usage = try await client.fetchUsage()
        } catch {
            usage = nil
            messages.append(error.localizedDescription)
        }

        do {
            resetCredits = try await client.fetchResetCredits()
        } catch {
            resetCredits = nil
            messages.append(error.localizedDescription)
        }

        let errorMessage = messages.isEmpty ? nil : messages.joined(separator: " ")
        return LimitSnapshotBuilder.make(
            usage: usage,
            resetCredits: resetCredits,
            now: now,
            errorMessage: errorMessage
        )
    }
}
