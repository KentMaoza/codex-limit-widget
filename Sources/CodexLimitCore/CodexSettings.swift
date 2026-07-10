import Foundation

public struct CodexSettings: Equatable, Sendable {
    public let model: String?
    public let reasoningEffort: String?

    public init(model: String? = nil, reasoningEffort: String? = nil) {
        self.model = model
        self.reasoningEffort = reasoningEffort
    }

    public static func parse(_ contents: String) -> CodexSettings {
        var values: [String: String] = [:]

        for rawLine in contents.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                break
            }

            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else {
                continue
            }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let rawValue = parts[1].trimmingCharacters(in: .whitespaces)
            guard rawValue.count >= 2, rawValue.first == "\"", rawValue.last == "\"" else {
                continue
            }
            values[key] = String(rawValue.dropFirst().dropLast())
        }

        return CodexSettings(
            model: values["model"],
            reasoningEffort: values["model_reasoning_effort"]
        )
    }

    public static func load(codexHome: URL? = nil) -> CodexSettings {
        let home: URL
        if let codexHome {
            home = codexHome
        } else if let value = ProcessInfo.processInfo.environment["CODEX_HOME"], !value.isEmpty {
            home = URL(fileURLWithPath: NSString(string: value).expandingTildeInPath)
        } else {
            home = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex")
        }

        let configURL = home.appending(path: "config.toml")
        guard let contents = try? String(contentsOf: configURL, encoding: .utf8) else {
            return CodexSettings()
        }
        return parse(contents)
    }
}
