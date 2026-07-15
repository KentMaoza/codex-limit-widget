import Foundation

public struct CodexLimitClient: Sendable {
    private static let productionUsageEndpoint = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private static let productionResetCreditsEndpoint = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!

    public let codexHome: URL
    public let timeoutSeconds: TimeInterval
    private let usageEndpoint: URL
    private let resetCreditsEndpoint: URL
    private let session: URLSession
    private let validatesProductionEndpoints: Bool

    public init(
        codexHome: URL? = nil,
        timeoutSeconds: TimeInterval = 20
    ) {
        self.codexHome = Self.resolveCodexHome(codexHome)
        self.usageEndpoint = Self.productionUsageEndpoint
        self.resetCreditsEndpoint = Self.productionResetCreditsEndpoint
        self.timeoutSeconds = timeoutSeconds
        self.session = .shared
        self.validatesProductionEndpoints = true
    }

    init(
        codexHome: URL? = nil,
        usageEndpoint: URL,
        resetCreditsEndpoint: URL,
        timeoutSeconds: TimeInterval = 20,
        session: URLSession,
        validatesProductionEndpoints: Bool = false
    ) {
        self.codexHome = Self.resolveCodexHome(codexHome)
        self.usageEndpoint = usageEndpoint
        self.resetCreditsEndpoint = resetCreditsEndpoint
        self.timeoutSeconds = timeoutSeconds
        self.session = session
        self.validatesProductionEndpoints = validatesProductionEndpoints
    }

    public func fetchUsage() async throws -> CodexUsageResponse {
        try await fetch(CodexUsageResponse.self, from: usageEndpoint)
    }

    public func fetchResetCredits() async throws -> ResetCreditsResponse {
        try await fetch(ResetCreditsResponse.self, from: resetCreditsEndpoint)
    }

    func loadSettings() -> CodexSettings {
        CodexSettings.load(codexHome: codexHome)
    }

    private func fetch<Response: Decodable>(_ responseType: Response.Type, from endpoint: URL) async throws -> Response {
        if validatesProductionEndpoints,
           (endpoint.scheme?.lowercased() != "https" || endpoint.host?.lowercased() != "chatgpt.com") {
            throw CodexLimitError.untrustedEndpoint
        }

        let auth = try loadAuth()
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "GET"
        request.timeoutInterval = timeoutSeconds
        request.setValue("Bearer \(auth.tokens.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("Codex Desktop", forHTTPHeaderField: "originator")
        request.setValue("CODEX", forHTTPHeaderField: "OAI-Product-Sku")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let accountId = accountId(from: auth.tokens.accessToken, fallback: auth.tokens.accountId) {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled && Task.isCancelled {
            throw CancellationError()
        } catch {
            throw CodexLimitError.transportFailure
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CodexLimitError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 429 {
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap(TimeInterval.init)
                throw CodexLimitError.rateLimited(retryAfter)
            }
            throw CodexLimitError.httpStatus(httpResponse.statusCode)
        }
        guard !data.isEmpty else {
            throw CodexLimitError.emptyResponse
        }
        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
           !contentType.localizedCaseInsensitiveContains("json") {
            throw CodexLimitError.unexpectedContentType(contentType)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw CodexLimitError.invalidJSON
        }
    }

    private func loadAuth() throws -> CodexAuth {
        let authURL = codexHome.appending(path: "auth.json")
        guard FileManager.default.fileExists(atPath: authURL.path) else {
            throw CodexLimitError.missingAuth(authURL.path)
        }

        let data = try Data(contentsOf: authURL)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(CodexAuth.self, from: data)
        } catch {
            throw CodexLimitError.invalidAuth(authURL.path)
        }
    }

    private func accountId(from token: String, fallback: String?) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2,
              let payloadData = Data(base64URLString: String(parts[1])),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let auth = json["https://api.openai.com/auth"] as? [String: Any]
        else {
            return fallback
        }

        return auth["chatgpt_account_id"] as? String ?? fallback
    }

    private static func resolveCodexHome(_ explicitHome: URL?) -> URL {
        if let explicitHome {
            return explicitHome
        }
        if let value = ProcessInfo.processInfo.environment["CODEX_HOME"], !value.isEmpty {
            return URL(fileURLWithPath: NSString(string: value).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex")
    }
}

public enum CodexLimitError: LocalizedError, Equatable, Sendable {
    case missingAuth(String)
    case invalidAuth(String)
    case untrustedEndpoint
    case transportFailure
    case invalidResponse
    case emptyResponse
    case unexpectedContentType(String)
    case invalidJSON
    case rateLimited(TimeInterval?)
    case httpStatus(Int)

    public var errorDescription: String? {
        switch self {
        case let .missingAuth(path):
            return "Could not find Codex login at \(path). Open Codex Desktop and sign in first."
        case let .invalidAuth(path):
            return "Could not read Codex login at \(path). Open Codex Desktop and sign in again."
        case .untrustedEndpoint:
            return "The Codex endpoint is not trusted."
        case .transportFailure:
            return "Could not reach the Codex endpoint."
        case .invalidResponse:
            return "The Codex endpoint returned an invalid response."
        case .emptyResponse:
            return "The Codex endpoint returned an empty response."
        case let .unexpectedContentType(contentType):
            return "The Codex endpoint returned \(contentType) instead of JSON."
        case .invalidJSON:
            return "The Codex endpoint returned invalid JSON."
        case let .rateLimited(retryAfter):
            if let retryAfter {
                return "Codex rate-limited this check. Try again after \(retryAfter.formatted()) seconds."
            }
            return "Codex rate-limited this check. Try again later."
        case let .httpStatus(status):
            if status == 401 || status == 403 {
                return "Codex rejected the saved login. Open Codex Desktop and sign in again."
            }
            return "The Codex endpoint returned HTTP \(status)."
        }
    }
}
