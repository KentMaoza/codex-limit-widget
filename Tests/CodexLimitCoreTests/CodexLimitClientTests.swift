@testable import CodexLimitCore
import Foundation
import XCTest

final class CodexLimitClientTests: XCTestCase {
    func testCodexHomePrecedenceAndResolutionAtInitialization() {
        withCodexHomeEnvironment("/tmp/codex-limit-environment") {
            let explicitHome = URL(fileURLWithPath: "/tmp/codex-limit-explicit")
            XCTAssertEqual(CodexLimitClient(codexHome: explicitHome).codexHome, explicitHome)

            let environmentClient = CodexLimitClient()
            XCTAssertEqual(environmentClient.codexHome.path, "/tmp/codex-limit-environment")

            setenv("CODEX_HOME", "/tmp/codex-limit-changed", 1)
            XCTAssertEqual(environmentClient.codexHome.path, "/tmp/codex-limit-environment")
        }

        withCodexHomeEnvironment(nil) {
            XCTAssertEqual(
                CodexLimitClient().codexHome,
                FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex")
            )
        }
    }

    func testResolvedHomeSuppliesAuthAndSettingsAndRequestMetadata() async throws {
        let fixture = try makeFixture(
            token: "header.payload.signature",
            accountID: "account-from-auth",
            config: "model = \"gpt-5.6-sol\"\nmodel_reasoning_effort = \"xhigh\"\n"
        )
        let requests = LockedRequests()
        StubURLProtocol.install { request in
            requests.append(request)
            return try Self.response(for: request, body: "{}")
        }
        let client = makeClient(codexHome: fixture.home)

        _ = try await client.fetchUsage()
        let settings = client.loadSettings()

        let request = try XCTUnwrap(requests.values.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.timeoutInterval, 20)
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer header.payload.signature")
        XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "account-from-auth")
        XCTAssertEqual(request.value(forHTTPHeaderField: "originator"), "Codex Desktop")
        XCTAssertEqual(request.value(forHTTPHeaderField: "OAI-Product-Sku"), "CODEX")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(settings, CodexSettings(model: "gpt-5.6-sol", reasoningEffort: "xhigh"))
    }

    func testJWTAccountIDTakesPrecedenceOverAuthFallback() async throws {
        let payload = Data(#"{"https://api.openai.com/auth":{"chatgpt_account_id":"account-from-jwt"}}"#.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let token = "header.\(payload).signature"
        let fixture = try makeFixture(token: token, accountID: "fallback-account")
        let requests = LockedRequests()
        StubURLProtocol.install { request in
            requests.append(request)
            return try Self.response(for: request, body: "{}")
        }

        _ = try await makeClient(codexHome: fixture.home).fetchUsage()

        XCTAssertEqual(requests.values.first?.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "account-from-jwt")
    }

    func testHTTPStatusAndAuthErrorsAreStable() async throws {
        let fixture = try makeFixture()
        let client = makeClient(codexHome: fixture.home)

        StubURLProtocol.install { request in
            try Self.response(for: request, statusCode: 500, body: "{}")
        }
        let serverError = await capturedError { try await client.fetchUsage() }
        XCTAssertEqual(serverError as? CodexLimitError, .httpStatus(500))
        XCTAssertEqual(serverError.localizedDescription, "The Codex endpoint returned HTTP 500.")

        StubURLProtocol.install { request in
            try Self.response(for: request, statusCode: 401, body: "{}")
        }
        let authError = await capturedError { try await client.fetchUsage() }
        XCTAssertEqual(authError as? CodexLimitError, .httpStatus(401))
        XCTAssertTrue(authError.localizedDescription.contains("sign in again"))
    }

    func testRateLimitParsesOnlyNumericRetryAfter() async throws {
        let fixture = try makeFixture()
        let client = makeClient(codexHome: fixture.home)

        StubURLProtocol.install { request in
            try Self.response(for: request, statusCode: 429, headers: ["Retry-After": "120.5"], body: "{}")
        }
        let numericError = await capturedError { try await client.fetchUsage() }
        XCTAssertEqual(numericError as? CodexLimitError, .rateLimited(120.5))

        StubURLProtocol.install { request in
            try Self.response(for: request, statusCode: 429, headers: ["Retry-After": "Wed, 21 Oct 2015 07:28:00 GMT"], body: "{}")
        }
        let dateError = await capturedError { try await client.fetchUsage() }
        XCTAssertEqual(dateError as? CodexLimitError, .rateLimited(nil))
    }

    func testRateLimitRejectsNonFiniteOverflowAndNegativeRetryAfter() async throws {
        let fixture = try makeFixture()
        let client = makeClient(codexHome: fixture.home)

        for value in ["nan", "inf", "1e9999", "-1"] {
            StubURLProtocol.install { request in
                try Self.response(for: request, statusCode: 429, headers: ["Retry-After": value], body: "{}")
            }

            let error = await capturedError { try await client.fetchUsage() }

            XCTAssertEqual(error as? CodexLimitError, .rateLimited(nil), "Retry-After: \(value)")
        }
    }

    func testEmptyContentTypeAndInvalidJSONErrorsAreStable() async throws {
        let fixture = try makeFixture()
        let client = makeClient(codexHome: fixture.home)

        StubURLProtocol.install { request in
            try Self.response(for: request, body: "")
        }
        let emptyError = await capturedError { try await client.fetchUsage() }
        XCTAssertEqual(emptyError as? CodexLimitError, .emptyResponse)

        StubURLProtocol.install { request in
            try Self.response(for: request, headers: ["Content-Type": "text/html"], body: "<html></html>")
        }
        let contentTypeError = await capturedError { try await client.fetchUsage() }
        XCTAssertEqual(contentTypeError as? CodexLimitError, .unexpectedContentType)

        StubURLProtocol.install { request in
            try Self.response(for: request, body: "not-json")
        }
        let invalidJSONError = await capturedError { try await client.fetchUsage() }
        XCTAssertEqual(invalidJSONError as? CodexLimitError, .invalidJSON)
    }

    func testUntrustedEndpointIsRejectedBeforeAuthorizationIsSent() async throws {
        let fixture = try makeFixture()
        let requests = LockedRequests()
        StubURLProtocol.install { request in
            requests.append(request)
            return try Self.response(for: request, body: "{}")
        }
        let client = CodexLimitClient(
            codexHome: fixture.home,
            usageEndpoint: URL(string: "http://example.com/usage")!,
            resetCreditsEndpoint: URL(string: "https://chatgpt.com/test/reset")!,
            timeoutSeconds: 20,
            session: makeSession(),
            validatesProductionEndpoints: true
        )

        let error = await capturedError { try await client.fetchUsage() }

        XCTAssertEqual(error as? CodexLimitError, .untrustedEndpoint)
        XCTAssertTrue(requests.values.isEmpty)
    }

    func testInternalInitializerAllowsAlternateTestEndpoint() async throws {
        let fixture = try makeFixture()
        let requests = LockedRequests()
        StubURLProtocol.install { request in
            requests.append(request)
            return try Self.response(for: request, body: "{}")
        }
        let client = CodexLimitClient(
            codexHome: fixture.home,
            usageEndpoint: URL(string: "http://test.invalid/usage")!,
            resetCreditsEndpoint: URL(string: "http://test.invalid/reset")!,
            session: makeSession()
        )

        _ = try await client.fetchUsage()

        XCTAssertEqual(requests.values.first?.url?.absoluteString, "http://test.invalid/usage")
    }

    func testTransportAndDecodingErrorsNeverEchoBearerToken() async throws {
        let token = "secret-bearer-token"
        let fixture = try makeFixture(token: token)
        let client = makeClient(codexHome: fixture.home)

        StubURLProtocol.install { _ in
            throw NSError(domain: token, code: 1, userInfo: [NSLocalizedDescriptionKey: token])
        }
        let transportError = await capturedError { try await client.fetchUsage() }
        XCTAssertEqual(transportError as? CodexLimitError, .transportFailure)
        XCTAssertFalse(transportError.localizedDescription.contains(token))

        StubURLProtocol.install { request in
            try Self.response(for: request, body: #"{"secret":"secret-bearer-token""#)
        }
        let decodingError = await capturedError { try await client.fetchUsage() }
        XCTAssertEqual(decodingError as? CodexLimitError, .invalidJSON)
        XCTAssertFalse(decodingError.localizedDescription.contains(token))

        StubURLProtocol.install { request in
            try Self.response(
                for: request,
                headers: ["Content-Type": "text/plain; bearer=\(token)"],
                body: "not-json"
            )
        }
        let contentTypeError = await capturedError { try await client.fetchUsage() }
        XCTAssertEqual(contentTypeError as? CodexLimitError, .unexpectedContentType)
        XCTAssertFalse(contentTypeError.localizedDescription.contains(token))
    }

    private func makeClient(codexHome: URL) -> CodexLimitClient {
        CodexLimitClient(
            codexHome: codexHome,
            usageEndpoint: URL(string: "https://chatgpt.com/test/usage")!,
            resetCreditsEndpoint: URL(string: "https://chatgpt.com/test/reset")!,
            timeoutSeconds: 20,
            session: makeSession()
        )
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func makeFixture(
        token: String = "test-token",
        accountID: String? = "test-account",
        config: String? = nil
    ) throws -> (home: URL, token: String) {
        let home = FileManager.default.temporaryDirectory
            .appending(path: "codex-limit-client-tests")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let accountLine = accountID.map { #", "account_id": "\#($0)""# } ?? ""
        try #"{"tokens":{"access_token":"\#(token)"\#(accountLine)}}"#
            .write(to: home.appending(path: "auth.json"), atomically: true, encoding: .utf8)
        if let config {
            try config.write(to: home.appending(path: "config.toml"), atomically: true, encoding: .utf8)
        }
        return (home, token)
    }

    private func capturedError<Value>(_ operation: () async throws -> Value) async -> Error {
        do {
            _ = try await operation()
            XCTFail("Expected operation to throw")
            return NSError(domain: "CodexLimitClientTests", code: 0)
        } catch {
            return error
        }
    }

    private static func response(
        for request: URLRequest,
        statusCode: Int = 200,
        headers: [String: String] = ["Content-Type": "application/json"],
        body: String
    ) throws -> (HTTPURLResponse, Data) {
        let response = try XCTUnwrap(HTTPURLResponse(
            url: try XCTUnwrap(request.url),
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headers
        ))
        return (response, Data(body.utf8))
    }

    private func withCodexHomeEnvironment(_ value: String?, perform body: () -> Void) {
        let previousValue = getenv("CODEX_HOME").map { String(cString: $0) }
        defer {
            if let previousValue {
                setenv("CODEX_HOME", previousValue, 1)
            } else {
                unsetenv("CODEX_HOME")
            }
        }

        if let value {
            setenv("CODEX_HOME", value, 1)
        } else {
            unsetenv("CODEX_HOME")
        }
        body()
    }
}

private final class LockedRequests: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []

    var values: [URLRequest] {
        lock.withLock { requests }
    }

    func append(_ request: URLRequest) {
        lock.withLock {
            requests.append(request)
        }
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: Handler?

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
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
