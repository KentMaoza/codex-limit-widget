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

    func testSnapshotBuildsFromCurrentUsageSchema() throws {
        let usage = try decode(CodexUsageResponse.self, from: """
        {
          "plan_type": "prolite",
          "rate_limit": {
            "allowed": true,
            "primary_window": {
              "used_percent": 3,
              "limit_window_seconds": 18000,
              "reset_after_seconds": 17416,
              "reset_at": 1783710647
            },
            "secondary_window": {
              "used_percent": 16,
              "limit_window_seconds": 604800,
              "reset_after_seconds": 565430,
              "reset_at": 1784258661
            }
          },
          "additional_rate_limits": [
            {
              "limit_name": "GPT-5.3-Codex-Spark",
              "metered_feature": "codex_bengalfox",
              "rate_limit": {
                "allowed": true,
                "primary_window": {
                  "used_percent": 0,
                  "limit_window_seconds": 18000,
                  "reset_after_seconds": 18000,
                  "reset_at": 1783711232
                },
                "secondary_window": {
                  "used_percent": 0,
                  "limit_window_seconds": 604800,
                  "reset_after_seconds": 604800,
                  "reset_at": 1784298032
                }
              }
            }
          ],
          "credits": {
            "balance": "12.5"
          }
        }
        """)

        let snapshot = LimitSnapshotBuilder.make(
            usage: usage,
            resetCredits: nil,
            settings: CodexSettings(model: "gpt-5.6-sol", reasoningEffort: "xhigh")
        )

        XCTAssertEqual(snapshot.planLabel, "Pro Lite")
        XCTAssertEqual(snapshot.windows.count, 4)
        XCTAssertEqual(snapshot.windows[2].title, "GPT-5.3-Codex-Spark · 5h")
        XCTAssertEqual(snapshot.windows[3].title, "GPT-5.3-Codex-Spark · Weekly")
        XCTAssertEqual(snapshot.creditBalance, "12.5")
        XCTAssertEqual(snapshot.activeModel, "gpt-5.6-sol")
        XCTAssertEqual(snapshot.reasoningEffort, "xhigh")
        XCTAssertEqual(snapshot.configurationLine, "gpt-5.6-sol · xhigh")
        XCTAssertEqual(snapshot.summaryLine, "5h 97% / W 84% / 12.5 cr")
        XCTAssertEqual(snapshot.statusTitle, "Capacity available")
        XCTAssertEqual(snapshot.balanceValue, "12.5")
        XCTAssertEqual(snapshot.balanceCaption, "credit balance")
        XCTAssertEqual(snapshot.compactBalance, "12.5 cr")
    }

    func testNotCheckedSnapshotDoesNotReportCapacity() {
        let snapshot = LimitSnapshot.notChecked

        XCTAssertTrue(snapshot.isNotChecked)
        XCTAssertNil(snapshot.checkedAt)
        XCTAssertTrue(snapshot.windows.isEmpty)
        XCTAssertEqual(snapshot.summaryLine, "Not checked yet")
        XCTAssertEqual(snapshot.statusTitle, "Not checked yet")
    }

    func testCurrentCodexSettingsParseFromRootConfig() {
        let settings = CodexSettings.parse("""
        model = "gpt-5.6-sol"
        model_reasoning_effort = "xhigh"

        [profiles.example]
        model = "should-not-override-root"
        """)

        XCTAssertEqual(settings.model, "gpt-5.6-sol")
        XCTAssertEqual(settings.reasoningEffort, "xhigh")
    }

    func testCurrentCodexSettingsLoadFromCodexHome() throws {
        let codexHome = FileManager.default.temporaryDirectory
            .appending(path: "codex-limit-settings-tests")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        try "model = \"gpt-5.6-sol\"\nmodel_reasoning_effort = \"xhigh\"\n"
            .write(to: codexHome.appending(path: "config.toml"), atomically: true, encoding: .utf8)

        let settings = CodexSettings.load(codexHome: codexHome)

        XCTAssertEqual(settings.model, "gpt-5.6-sol")
        XCTAssertEqual(settings.reasoningEffort, "xhigh")
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

    func testOldSnapshotRemainsDecodable() throws {
        let snapshot = try decode(LimitSnapshot.self, from: """
        {
          "generatedAt": 0,
          "planLabel": "Codex",
          "availableResetCount": 2,
          "windows": [],
          "errorMessage": null
        }
        """)

        XCTAssertNil(snapshot.creditBalance)
        XCTAssertNil(snapshot.activeModel)
        XCTAssertEqual(snapshot.balanceValue, "2")
        XCTAssertEqual(snapshot.balanceCaption, "resets banked")
        XCTAssertEqual(snapshot.compactBalance, "2R")
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from json: String) throws -> Value {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Value.self, from: Data(json.utf8))
    }
}
