import Foundation
import Security

public struct CodexLimitSnapshotStore: Sendable {
    public static let appGroupIdentifier = "group.com.hamlet.codex-limit-widget"
    public static let widgetBundleIdentifier = "com.hamlet.CodexLimitWidget.LimitWidget"
    public static let fileName = "limit-snapshot.json"

    public let fileURL: URL

    public static var runtimeDefault: CodexLimitSnapshotStore {
        #if DEBUG
        CodexLimitSnapshotStore(fileURL: localWidgetContainerFileURL())
        #else
        CodexLimitSnapshotStore()
        #endif
    }

    public init(fileURL: URL? = nil, appGroupIdentifier: String = Self.appGroupIdentifier) {
        self.fileURL = fileURL ?? Self.defaultFileURL(appGroupIdentifier: appGroupIdentifier)
    }

    public func load() -> LimitSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return try? JSONDecoder().decode(LimitSnapshot.self, from: data)
    }

    public func save(_ snapshot: LimitSnapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }

    public static func localWidgetContainerFileURL(
        userHome: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        userHome
            .appending(path: "Library/Containers")
            .appending(path: widgetBundleIdentifier)
            .appending(path: "Data/Library/Application Support/Codex Limit Widget")
            .appending(path: fileName)
    }

    private static func defaultFileURL(appGroupIdentifier: String) -> URL {
        let supportURL = supportFileURL()
        if Bundle.main.bundleIdentifier == widgetBundleIdentifier,
           !hasAppGroupEntitlement(appGroupIdentifier) {
            return supportURL
        }

        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return containerURL.appending(path: fileName)
        }

        return supportURL
    }

    private static func supportFileURL() -> URL {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
        return supportURL.appending(path: "Codex Limit Widget").appending(path: fileName)
    }

    private static func hasAppGroupEntitlement(_ appGroupIdentifier: String) -> Bool {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(
                task,
                "com.apple.security.application-groups" as CFString,
                nil
              ),
              let groups = value as? [String]
        else {
            return false
        }

        return groups.contains(appGroupIdentifier)
    }
}
