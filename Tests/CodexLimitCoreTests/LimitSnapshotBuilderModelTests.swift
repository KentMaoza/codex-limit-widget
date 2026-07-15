import CodexLimitCore
import Foundation
import XCTest

final class LimitSnapshotBuilderModelTests: XCTestCase {
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

        XCTAssertEqual(snapshot.planLabel, "ChatGPT Pro")
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

    func testSoleBasePrimarySevenDayWindowIsWeekly() throws {
        let snapshot = LimitSnapshotBuilder.make(
            usage: try usage(from: """
            {
              "rate_limit": {
                "primary_window": {
                  "used_percent": 35,
                  "limit_window_seconds": 604800,
                  "reset_after_seconds": 18000
                }
              }
            }
            """),
            resetCredits: nil
        )

        XCTAssertEqual(snapshot.windows.count, 1)
        XCTAssertEqual(snapshot.windows[0].kind, .weekly)
        XCTAssertEqual(snapshot.windows[0].id, "weekly")
        XCTAssertEqual(snapshot.windows[0].title, "Weekly limit")
    }

    func testSoleNamedPrimarySevenDayWindowIsNamedWeekly() throws {
        let snapshot = LimitSnapshotBuilder.make(
            usage: try usage(from: """
            {
              "additional_rate_limits": [
                {
                  "limit_name": "GPT-5.3-Codex-Spark",
                  "rate_limit": {
                    "primary_window": {
                      "used_percent": 12,
                      "limit_window_seconds": 604800
                    }
                  }
                }
              ]
            }
            """),
            resetCredits: nil
        )

        XCTAssertEqual(snapshot.windows.count, 1)
        XCTAssertEqual(snapshot.windows[0].kind, .weekly)
        XCTAssertEqual(snapshot.windows[0].id, "additional-0-weekly")
        XCTAssertEqual(snapshot.windows[0].title, "GPT-5.3-Codex-Spark · Weekly")
    }

    func testEighteenThousandSecondWindowRemainsFiveHour() throws {
        let snapshot = LimitSnapshotBuilder.make(
            usage: try usage(from: """
            {
              "rate_limit": {
                "primary_window": {
                  "used_percent": 28,
                  "limit_window_seconds": 18000
                }
              }
            }
            """),
            resetCredits: nil
        )

        XCTAssertEqual(snapshot.windows[0].kind, .fiveHour)
        XCTAssertEqual(snapshot.windows[0].id, "five-hour")
        XCTAssertEqual(snapshot.windows[0].title, "5h limit")
    }

    func testExplicitUnknownDurationIsGenericAndIgnoresResetAfterSeconds() throws {
        let snapshot = LimitSnapshotBuilder.make(
            usage: try usage(from: """
            {
              "rate_limit": {
                "primary_window": {
                  "used_percent": 10,
                  "limit_window_seconds": 3600,
                  "reset_after_seconds": 18000
                }
              }
            }
            """),
            resetCredits: nil
        )

        XCTAssertEqual(snapshot.windows[0].kind, .generic)
        XCTAssertEqual(snapshot.windows[0].id, "primary")
        XCTAssertEqual(snapshot.windows[0].title, "1h limit")
    }

    func testMissingDurationsUsePrimaryAndSecondaryPosition() throws {
        let snapshot = LimitSnapshotBuilder.make(
            usage: try usage(from: """
            {
              "rate_limit": {
                "primary_window": { "used_percent": 10 },
                "secondary_window": { "used_percent": 20 }
              }
            }
            """),
            resetCredits: nil
        )

        XCTAssertEqual(snapshot.windows.map(\.kind), [.fiveHour, .weekly])
        XCTAssertEqual(snapshot.windows.map(\.id), ["five-hour", "weekly"])
    }

    func testCompactWindowsSelectExactBaseIDsInsteadOfNamedWindows() {
        let snapshot = LimitSnapshot(
            generatedAt: Date(),
            planLabel: "Codex",
            availableResetCount: 0,
            windows: [
                window(id: "additional-0-five-hour", kind: .fiveHour),
                window(id: "additional-0-weekly", kind: .weekly),
                window(id: "five-hour", kind: .fiveHour),
                window(id: "weekly", kind: .weekly)
            ],
            errorMessage: nil
        )

        XCTAssertEqual(snapshot.fiveHourWindow?.id, "five-hour")
        XCTAssertEqual(snapshot.weeklyWindow?.id, "weekly")
    }

    func testCompactWindowsDoNotFallBackToNamedWindows() {
        let snapshot = LimitSnapshot(
            generatedAt: Date(),
            planLabel: "Codex",
            availableResetCount: 0,
            windows: [
                window(id: "additional-0-five-hour", kind: .fiveHour),
                window(id: "additional-0-weekly", kind: .weekly)
            ],
            errorMessage: nil
        )

        XCTAssertNil(snapshot.fiveHourWindow)
        XCTAssertNil(snapshot.weeklyWindow)
    }

    private func usage(from json: String) throws -> CodexUsageResponse {
        try decode(CodexUsageResponse.self, from: json)
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from json: String) throws -> Value {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Value.self, from: Data(json.utf8))
    }

    private func window(id: String, kind: LimitWindowKind) -> LimitWindowSnapshot {
        LimitWindowSnapshot(
            id: id,
            kind: kind,
            title: id,
            usedPercent: 0,
            remainingPercent: 100,
            resetAfterSeconds: nil,
            resetAt: nil
        )
    }
}
