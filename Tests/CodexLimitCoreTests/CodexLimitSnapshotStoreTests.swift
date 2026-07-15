import CodexLimitCore
import Foundation
import XCTest

final class CodexLimitSnapshotStoreTests: XCTestCase {
    func testSnapshotStoreRoundTripsSanitizedData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "codex-limit-widget-tests")
            .appending(path: UUID().uuidString)
        let fileURL = directory.appending(path: "snapshot.json")
        let store = CodexLimitSnapshotStore(fileURL: fileURL)
        let snapshot = LimitSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            planLabel: "Codex",
            availableResetCount: 1,
            windows: [
                LimitWindowSnapshot(
                    id: "five-hour",
                    kind: .fiveHour,
                    title: "5h limit",
                    usedPercent: 10,
                    remainingPercent: 90,
                    resetAfterSeconds: 600,
                    resetAt: nil
                )
            ],
            errorMessage: nil
        )

        try store.save(snapshot)

        XCTAssertEqual(store.load(), snapshot)
        let savedText = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(savedText.contains("accessToken"))
        XCTAssertFalse(savedText.contains("Authorization"))
    }

    func testWidgetMirrorPath() {
        let home = URL(fileURLWithPath: "/tmp/codex-limit-home")
        let mirrorURL = CodexLimitSnapshotStore.localWidgetContainerFileURL(userHome: home)

        XCTAssertEqual(
            mirrorURL.path,
            "/tmp/codex-limit-home/Library/Containers/com.hamlet.CodexLimitWidget.LimitWidget/Data/Library/Application Support/Codex Limit Widget/limit-snapshot.json"
        )
    }
}
