import CodexLimitCore
import Foundation

enum CheckFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case let .failed(message):
            return message
        }
    }
}

func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw CheckFailure.failed(message)
    }
}

func checkSnapshotBuildsFromUsageAndResetCredits() throws {
    let usageJSON = Data("""
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
    """.utf8)

    let creditsJSON = Data("""
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
    """.utf8)

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let usage = try decoder.decode(CodexUsageResponse.self, from: usageJSON)
    let credits = try decoder.decode(ResetCreditsResponse.self, from: creditsJSON)
    let snapshot = LimitSnapshotBuilder.make(
        usage: usage,
        resetCredits: credits,
        now: Date(timeIntervalSince1970: 1_800_000_000)
    )

    try check(snapshot.planLabel == "Chatgpt Pro", "plan label decode failed")
    try check(snapshot.availableResetCount == 2, "reset count should prefer reset-credit endpoint")
    try check(snapshot.fiveHourWindow?.remainingPercent == 72, "5h remaining percent mismatch")
    try check(snapshot.weeklyWindow?.remainingPercent == 65, "weekly remaining percent mismatch")
    try check(snapshot.summaryLine == "5h 72% / W 65% / 2R", "summary line mismatch")
}

func checkSnapshotBuildsFromCurrentUsageSchema() throws {
    let usageJSON = Data("""
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
    """.utf8)

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let usage = try decoder.decode(CodexUsageResponse.self, from: usageJSON)
    let snapshot = LimitSnapshotBuilder.make(
        usage: usage,
        resetCredits: nil,
        settings: CodexSettings(model: "gpt-5.6-sol", reasoningEffort: "xhigh")
    )

    try check(snapshot.planLabel == "Pro Lite", "current plan label mismatch")
    try check(snapshot.windows.count == 4, "named rate-limit windows should be included")
    try check(snapshot.windows[2].title == "GPT-5.3-Codex-Spark · 5h", "named 5h window title mismatch")
    try check(snapshot.windows[3].title == "GPT-5.3-Codex-Spark · Weekly", "named weekly window title mismatch")
    try check(snapshot.creditBalance == "12.5", "flexible credit balance mismatch")
    try check(snapshot.activeModel == "gpt-5.6-sol", "active model snapshot mismatch")
    try check(snapshot.reasoningEffort == "xhigh", "reasoning effort snapshot mismatch")
    try check(snapshot.configurationLine == "gpt-5.6-sol · xhigh", "configuration summary mismatch")
    try check(snapshot.summaryLine == "5h 97% / W 84% / 12.5 cr", "current menu summary mismatch")
    try check(snapshot.statusTitle == "Capacity available", "current capacity status mismatch")
    try check(snapshot.balanceValue == "12.5", "credit balance display mismatch")
    try check(snapshot.balanceCaption == "credit balance", "credit balance caption mismatch")
    try check(snapshot.compactBalance == "12.5 cr", "compact credit balance mismatch")
}

func checkRefreshPolicyUsesOneMinute() throws {
    try check(CodexLimitRefreshPolicy.refreshIntervalSeconds == 60, "refresh seconds must be 60")
    try check(CodexLimitRefreshPolicy.refreshInterval == 60, "refresh interval must be 60 seconds")
}

func checkCurrentCodexSettingsParseFromRootConfig() throws {
    let settings = CodexSettings.parse("""
    model = "gpt-5.6-sol"
    model_reasoning_effort = "xhigh"

    [profiles.example]
    model = "should-not-override-root"
    """)

    try check(settings.model == "gpt-5.6-sol", "current model setting mismatch")
    try check(settings.reasoningEffort == "xhigh", "reasoning effort setting mismatch")
}

func checkCurrentCodexSettingsLoadFromCodexHome() throws {
    let codexHome = FileManager.default.temporaryDirectory
        .appending(path: "codex-limit-settings-checks")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
    try "model = \"gpt-5.6-sol\"\nmodel_reasoning_effort = \"xhigh\"\n"
        .write(to: codexHome.appending(path: "config.toml"), atomically: true, encoding: .utf8)

    let settings = CodexSettings.load(codexHome: codexHome)

    try check(settings.model == "gpt-5.6-sol", "loaded model setting mismatch")
    try check(settings.reasoningEffort == "xhigh", "loaded reasoning effort mismatch")
}

func checkNotCheckedSnapshotIsTruthful() throws {
    let snapshot = LimitSnapshot.notChecked
    try check(snapshot.isNotChecked, "not-checked snapshot should be identifiable")
    try check(snapshot.checkedAt == nil, "not-checked snapshot should not expose a checked date")
    try check(snapshot.windows.isEmpty, "not-checked snapshot should not include fake windows")
    try check(snapshot.summaryLine == "Not checked yet", "not-checked summary mismatch")
    try check(snapshot.statusTitle == "Not checked yet", "not-checked status mismatch")
}

func checkZeroDurationIsImmediate() throws {
    try check(CodexLimitDateFormatting.duration(seconds: 0) == "now", "zero duration should be now")
    try check(CodexLimitDateFormatting.duration(seconds: -10) == "now", "negative duration should be now")
}

func checkSnapshotStoreIsSanitized() throws {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "codex-limit-widget-checks")
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
    try check(store.load() == snapshot, "saved snapshot did not round-trip")

    let savedText = try String(contentsOf: fileURL, encoding: .utf8)
    try check(!savedText.contains("accessToken"), "snapshot must not include accessToken")
    try check(!savedText.contains("Authorization"), "snapshot must not include Authorization")
}

func checkOldSnapshotRemainsDecodable() throws {
    let data = Data("""
    {
      "generatedAt": 0,
      "planLabel": "Codex",
      "availableResetCount": 2,
      "windows": [],
      "errorMessage": null
    }
    """.utf8)

    let snapshot = try JSONDecoder().decode(LimitSnapshot.self, from: data)

    try check(snapshot.creditBalance == nil, "old snapshot should not invent credits")
    try check(snapshot.activeModel == nil, "old snapshot should not invent a model")
    try check(snapshot.balanceValue == "2", "old snapshot reset display mismatch")
    try check(snapshot.balanceCaption == "resets banked", "old snapshot caption mismatch")
    try check(snapshot.compactBalance == "2R", "old snapshot compact balance mismatch")
}

func checkWidgetMirrorPath() throws {
    let home = URL(fileURLWithPath: "/tmp/codex-limit-home")
    let mirrorURL = CodexLimitSnapshotStore.localWidgetContainerFileURL(userHome: home)
    try check(
        mirrorURL.path == "/tmp/codex-limit-home/Library/Containers/com.hamlet.CodexLimitWidget.LimitWidget/Data/Library/Application Support/Codex Limit Widget/limit-snapshot.json",
        "widget mirror path mismatch"
    )
}

do {
    try checkSnapshotBuildsFromUsageAndResetCredits()
    try checkSnapshotBuildsFromCurrentUsageSchema()
    try checkRefreshPolicyUsesOneMinute()
    try checkCurrentCodexSettingsParseFromRootConfig()
    try checkCurrentCodexSettingsLoadFromCodexHome()
    try checkNotCheckedSnapshotIsTruthful()
    try checkZeroDurationIsImmediate()
    try checkSnapshotStoreIsSanitized()
    try checkOldSnapshotRemainsDecodable()
    try checkWidgetMirrorPath()
    print("CodexLimitCoreChecks passed")
} catch {
    fputs("CodexLimitCoreChecks failed: \(error)\n", stderr)
    exit(1)
}
