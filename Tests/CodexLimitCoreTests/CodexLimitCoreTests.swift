import CodexLimitCore
import Foundation
import XCTest

final class CodexLimitCoreTests: XCTestCase {
    func testSnapshotBuildsFromUsageAndResetCredits() throws {
        let usage = try decode(CodexUsageResponse.self, from: """
        {
          "plan_type": "chatgpt_pro",
          "rate_limit": {
            "allowed": true,
            "limit_reached": false,
            "primary_window": {
              "used_percent": 28,
              "limit_window_seconds": 18000,
              "reset_after_seconds": 3600,
              "reset_at": 1800003600
            },
            "secondary_window": {
              "used_percent": 35,
              "limit_window_seconds": 604800,
              "reset_after_seconds": 172800,
              "reset_at": 1800172800
            }
          },
          "rate_limit_reset_credits": {
            "available_count": 1
          }
        }
        """)
        let credits = try decode(ResetCreditsResponse.self, from: """
        {
          "available_count": 2,
          "credits": [
            {
              "id": 123,
              "reset_type": "weekly",
              "status": "available",
              "expires_at": "2026-06-25T00:00:00Z"
            }
          ]
        }
        """)

        let snapshot = LimitSnapshotBuilder.make(
            usage: usage,
            resetCredits: credits,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertEqual(snapshot.planLabel, "Chatgpt Pro")
        XCTAssertEqual(snapshot.availableResetCount, 2)
        XCTAssertEqual(snapshot.fiveHourWindow?.remainingPercent, 72)
        XCTAssertEqual(snapshot.weeklyWindow?.remainingPercent, 65)
        XCTAssertEqual(snapshot.summaryLine, "5h 72% / W 65% / 2R")
    }

    func testNotCheckedSnapshotDoesNotReportCapacity() {
        let snapshot = LimitSnapshot.notChecked

        XCTAssertTrue(snapshot.isNotChecked)
        XCTAssertNil(snapshot.checkedAt)
        XCTAssertTrue(snapshot.windows.isEmpty)
        XCTAssertEqual(snapshot.summaryLine, "Not checked yet")
        XCTAssertEqual(snapshot.statusTitle, "Not checked yet")
    }

    func testDurationZeroIsImmediate() {
        XCTAssertEqual(CodexLimitDateFormatting.duration(seconds: 0), "now")
        XCTAssertEqual(CodexLimitDateFormatting.duration(seconds: -10), "now")
    }

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

    private func decode<Value: Decodable>(_ type: Value.Type, from json: String) throws -> Value {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Value.self, from: Data(json.utf8))
    }
}
