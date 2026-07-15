@testable import CodexLimitCore
import Foundation
import XCTest

final class CodexLimitServiceTests: XCTestCase {
    func testUsageAndResetRequestsOverlapAndRecoveryRebuildsSnapshot() async throws {
        let fixture = try makeFixture(config: "model = \"gpt-5.6-sol\"\n")
        let allRequestsStarted = expectation(description: "Both requests started")
        let gate = OverlapGate(requiredArrivals: 2, expectation: allRequestsStarted)
        ServiceURLProtocol.install { request in
            try Self.successResponse(for: request, gate: gate)
        }
        let previous = previousSnapshot(errorMessage: "Old failure")
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let service = makeService(home: fixture)

        async let refreshResult = service.refresh(previous: previous, now: now)
        defer {
            gate.releaseAll()
        }
        await fulfillment(of: [allRequestsStarted], timeout: 1)
        let arrivalCount = gate.arrivalCount
        gate.releaseAll()
        let result = try await refreshResult

        XCTAssertEqual(arrivalCount, 2)
        XCTAssertEqual(result.snapshot.generatedAt, now)
        XCTAssertEqual(result.snapshot.lastAttemptAt, now)
        XCTAssertEqual(result.snapshot.planLabel, "ChatGPT Pro")
        XCTAssertEqual(result.snapshot.availableResetCount, 2)
        XCTAssertEqual(result.snapshot.fiveHourWindow?.remainingPercent, 72)
        XCTAssertEqual(result.snapshot.activeModel, "gpt-5.6-sol")
        XCTAssertNil(result.snapshot.errorMessage)
        XCTAssertEqual(result.nextAllowedRefreshDelay, 60)
    }

    func testCancellationPropagatesInsteadOfCreatingErrorSnapshot() async throws {
        let fixture = try makeFixture()
        let starts = LockedDates()
        ServiceURLProtocol.install { request in
            starts.append(Date())
            return try Self.successResponse(for: request, delay: 1)
        }
        let service = makeService(home: fixture)
        let previous = previousSnapshot()
        let task = Task {
            try await service.refresh(previous: previous, now: Date())
        }
        for _ in 0..<100 where starts.values.count < 2 {
            try await Task.sleep(for: .milliseconds(5))
        }

        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertEqual(starts.values.count, 2)
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    func testDuplicateTotalFailurePreservesAllPreviousFields() async throws {
        let fixture = try makeFixture()
        ServiceURLProtocol.install { request in
            try Self.response(for: request, statusCode: 500)
        }
        let previous = previousSnapshot()
        let now = Date(timeIntervalSince1970: 1_900_000_000)

        let result = try await makeService(home: fixture).refresh(previous: previous, now: now)

        XCTAssertEqual(result.snapshot.generatedAt, previous.generatedAt)
        XCTAssertEqual(result.snapshot.lastAttemptAt, now)
        XCTAssertEqual(result.snapshot.planLabel, previous.planLabel)
        XCTAssertEqual(result.snapshot.availableResetCount, previous.availableResetCount)
        XCTAssertEqual(result.snapshot.creditBalance, previous.creditBalance)
        XCTAssertEqual(result.snapshot.activeModel, previous.activeModel)
        XCTAssertEqual(result.snapshot.reasoningEffort, previous.reasoningEffort)
        XCTAssertEqual(result.snapshot.windows, previous.windows)
        XCTAssertEqual(result.snapshot.errorMessage, "The Codex endpoint returned HTTP 500.")
        XCTAssertEqual(result.nextAllowedRefreshDelay, 60)
    }

    func testDistinctFailuresArePreservedAndGreatestRetryAfterWins() async throws {
        let fixture = try makeFixture()
        ServiceURLProtocol.install { request in
            if request.url?.path.hasSuffix("/usage") == true {
                return try Self.response(for: request, statusCode: 429, headers: ["Retry-After": "90"])
            }
            return try Self.response(for: request, statusCode: 429, headers: ["Retry-After": "120"])
        }

        let result = try await makeService(home: fixture).refresh(previous: previousSnapshot(), now: Date())

        XCTAssertEqual(
            result.snapshot.errorMessage,
            "Codex rate-limited this check. Try again after 90 seconds. Codex rate-limited this check. Try again after 120 seconds."
        )
        XCTAssertEqual(result.nextAllowedRefreshDelay, 120)
    }

    func testInitialUsageFailureRetainsNotCheckedDataAndRecordsAttempt() async throws {
        let fixture = try makeFixture()
        ServiceURLProtocol.install { request in
            try Self.response(for: request, statusCode: 500)
        }
        let now = Date(timeIntervalSince1970: 1_900_000_000)

        let result = try await makeService(home: fixture).refresh(previous: nil, now: now)

        XCTAssertEqual(result.snapshot.generatedAt, LimitSnapshot.notChecked.generatedAt)
        XCTAssertEqual(result.snapshot.lastAttemptAt, now)
        XCTAssertEqual(result.snapshot.planLabel, LimitSnapshot.notChecked.planLabel)
        XCTAssertTrue(result.snapshot.windows.isEmpty)
        XCTAssertNotNil(result.snapshot.errorMessage)
    }

    func testResetFailureWithoutUsageCreditFallbackKeepsWindowsAndPartialError() async throws {
        let fixture = try makeFixture()
        ServiceURLProtocol.install { request in
            if request.url?.path.hasSuffix("/usage") == true {
                return try Self.usageResponse(for: request, includesResetCount: false, includesBalance: false)
            }
            return try Self.response(for: request, statusCode: 500)
        }
        let now = Date(timeIntervalSince1970: 1_900_000_000)

        let result = try await makeService(home: fixture).refresh(previous: previousSnapshot(), now: now)

        XCTAssertEqual(result.snapshot.generatedAt, now)
        XCTAssertEqual(result.snapshot.fiveHourWindow?.remainingPercent, 72)
        XCTAssertEqual(result.snapshot.errorMessage, "The Codex endpoint returned HTTP 500.")
    }

    func testUsageResetCountSuppressesResetFailure() async throws {
        let fixture = try makeFixture()
        ServiceURLProtocol.install { request in
            if request.url?.path.hasSuffix("/usage") == true {
                return try Self.usageResponse(for: request, includesResetCount: true, includesBalance: false)
            }
            return try Self.response(for: request, statusCode: 500)
        }

        let result = try await makeService(home: fixture).refresh(previous: nil, now: Date())

        XCTAssertEqual(result.snapshot.availableResetCount, 1)
        XCTAssertNil(result.snapshot.errorMessage)
    }

    func testUsageBalanceSuppressesResetFailure() async throws {
        let fixture = try makeFixture()
        ServiceURLProtocol.install { request in
            if request.url?.path.hasSuffix("/usage") == true {
                return try Self.usageResponse(for: request, includesResetCount: false, includesBalance: true)
            }
            return try Self.response(for: request, statusCode: 500)
        }

        let result = try await makeService(home: fixture).refresh(previous: nil, now: Date())

        XCTAssertEqual(result.snapshot.creditBalance, "12.5")
        XCTAssertNil(result.snapshot.errorMessage)
    }

    private func makeFixture(config: String? = nil) throws -> URL {
        let home = FileManager.default.temporaryDirectory
            .appending(path: "codex-limit-service-tests")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try #"{"tokens":{"access_token":"test-token","account_id":"test-account"}}"#
            .write(to: home.appending(path: "auth.json"), atomically: true, encoding: .utf8)
        if let config {
            try config.write(to: home.appending(path: "config.toml"), atomically: true, encoding: .utf8)
        }
        return home
    }

    private func makeService(home: URL) -> CodexLimitService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ServiceURLProtocol.self]
        return CodexLimitService(client: CodexLimitClient(
            codexHome: home,
            usageEndpoint: URL(string: "https://chatgpt.com/test/usage")!,
            resetCreditsEndpoint: URL(string: "https://chatgpt.com/test/reset")!,
            session: URLSession(configuration: configuration)
        ))
    }

    private func previousSnapshot(errorMessage: String? = nil) -> LimitSnapshot {
        LimitSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            lastAttemptAt: Date(timeIntervalSince1970: 1_800_000_010),
            planLabel: "Previous Plan",
            availableResetCount: 7,
            creditBalance: "42",
            activeModel: "previous-model",
            reasoningEffort: "previous-effort",
            windows: [
                LimitWindowSnapshot(
                    id: "five-hour",
                    kind: .fiveHour,
                    title: "Previous window",
                    usedPercent: 10,
                    remainingPercent: 90,
                    resetAfterSeconds: 300,
                    resetAt: nil
                )
            ],
            errorMessage: errorMessage
        )
    }

    private static func successResponse(for request: URLRequest, delay: TimeInterval) throws -> ServiceStubResponse {
        if request.url?.path.hasSuffix("/usage") == true {
            return try usageResponse(for: request, includesResetCount: true, includesBalance: false, delay: delay)
        }
        return try response(
            for: request,
            body: #"{"available_count":2,"credits":[]}"#,
            delay: delay
        )
    }

    private static func successResponse(for request: URLRequest, gate: OverlapGate) throws -> ServiceStubResponse {
        if request.url?.path.hasSuffix("/usage") == true {
            return try usageResponse(
                for: request,
                includesResetCount: true,
                includesBalance: false,
                gate: gate
            )
        }
        return try response(
            for: request,
            body: #"{"available_count":2,"credits":[]}"#,
            gate: gate
        )
    }

    private static func usageResponse(
        for request: URLRequest,
        includesResetCount: Bool,
        includesBalance: Bool,
        delay: TimeInterval = 0,
        gate: OverlapGate? = nil
    ) throws -> ServiceStubResponse {
        let resetCount = includesResetCount ? #", "rate_limit_reset_credits":{"available_count":1}"# : ""
        let balance = includesBalance ? #", "credits":{"balance":"12.5"}"# : ""
        return try response(for: request, body: """
        {
          "plan_type": "chatgpt_pro",
          "rate_limit": {
            "primary_window": {
              "used_percent": 28,
              "limit_window_seconds": 18000
            }
          }
          \(resetCount)
          \(balance)
        }
        """, delay: delay, gate: gate)
    }

    private static func response(
        for request: URLRequest,
        statusCode: Int = 200,
        headers: [String: String] = ["Content-Type": "application/json"],
        body: String = "{}",
        delay: TimeInterval = 0,
        gate: OverlapGate? = nil
    ) throws -> ServiceStubResponse {
        ServiceStubResponse(
            response: try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: headers
            )),
            data: Data(body.utf8),
            delay: delay,
            gate: gate
        )
    }
}

private struct ServiceStubResponse: @unchecked Sendable {
    let response: HTTPURLResponse
    let data: Data
    let delay: TimeInterval
    let gate: OverlapGate?
}

private final class OverlapGate: @unchecked Sendable {
    private let lock = NSLock()
    private let requiredArrivals: Int
    private let expectation: XCTestExpectation
    private var deliveries: [@Sendable () -> Void] = []
    private var totalArrivals = 0
    private var isReleased = false
    private var fulfilledExpectation = false

    init(requiredArrivals: Int, expectation: XCTestExpectation) {
        self.requiredArrivals = requiredArrivals
        self.expectation = expectation
    }

    var arrivalCount: Int {
        lock.withLock { totalArrivals }
    }

    func enqueue(_ delivery: @escaping @Sendable () -> Void) {
        let actions = lock.withLock { () -> (fulfill: Bool, deliverNow: Bool) in
            totalArrivals += 1
            let shouldFulfill = !fulfilledExpectation && totalArrivals >= requiredArrivals
            if shouldFulfill {
                fulfilledExpectation = true
            }
            if !isReleased {
                deliveries.append(delivery)
            }
            return (shouldFulfill, isReleased)
        }
        if actions.fulfill {
            expectation.fulfill()
        }
        if actions.deliverNow {
            delivery()
        }
    }

    func releaseAll() {
        let pendingDeliveries = lock.withLock { () -> [@Sendable () -> Void] in
            isReleased = true
            defer {
                deliveries.removeAll()
            }
            return deliveries
        }
        for delivery in pendingDeliveries {
            delivery()
        }
    }
}

private final class LockedDates: @unchecked Sendable {
    private let lock = NSLock()
    private var dates: [Date] = []

    var values: [Date] {
        lock.withLock { dates }
    }

    func append(_ date: Date) {
        lock.withLock {
            dates.append(date)
        }
    }
}

private final class ServiceURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> ServiceStubResponse

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: Handler?
    private let stateLock = NSLock()
    private var stopped = false

    static func install(_ handler: @escaping Handler) {
        lock.withLock {
            self.handler = handler
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let handler = Self.lock.withLock { Self.handler }
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        do {
            let stub = try handler(request)
            let deliver: @Sendable () -> Void = { [self] in
                guard !stateLock.withLock({ stopped }) else {
                    return
                }
                client?.urlProtocol(self, didReceive: stub.response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: stub.data)
                client?.urlProtocolDidFinishLoading(self)
            }
            if let gate = stub.gate {
                gate.enqueue(deliver)
            } else {
                DispatchQueue.global().asyncAfter(deadline: .now() + stub.delay, execute: deliver)
            }
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        stateLock.withLock {
            stopped = true
        }
    }
}
