import CodexLimitCore
import Foundation
import XCTest

final class CodexSettingsDateTests: XCTestCase {
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

    func testRefreshPolicyUsesSixtySeconds() {
        XCTAssertEqual(CodexLimitRefreshPolicy.refreshIntervalSeconds, 60)
        XCTAssertEqual(CodexLimitRefreshPolicy.refreshInterval, 60)
    }
}
