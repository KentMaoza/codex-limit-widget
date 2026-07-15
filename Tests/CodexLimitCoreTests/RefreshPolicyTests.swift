@testable import CodexLimitCore
import XCTest

final class RefreshPolicyTests: XCTestCase {
    func testDelayUntilNextStartSubtractsElapsedWork() {
        XCTAssertEqual(
            CodexLimitRefreshPolicy.delayUntilNextStart(elapsed: 12, retryAfterDelay: nil),
            48
        )
    }

    func testDelayUntilNextStartHonorsExtendedServerDelay() {
        XCTAssertEqual(
            CodexLimitRefreshPolicy.delayUntilNextStart(elapsed: 12, retryAfterDelay: 120),
            120
        )
    }

    func testDelayUntilNextStartTreatsSixtySecondRetryAfterAsResponseRelative() {
        XCTAssertEqual(
            CodexLimitRefreshPolicy.delayUntilNextStart(elapsed: 12, retryAfterDelay: 60),
            60
        )
    }

    func testDelayUntilNextStartNeverReturnsNegativeValue() {
        XCTAssertEqual(
            CodexLimitRefreshPolicy.delayUntilNextStart(elapsed: 121, retryAfterDelay: nil),
            0
        )
    }
}
