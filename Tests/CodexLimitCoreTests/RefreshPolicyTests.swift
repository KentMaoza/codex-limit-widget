@testable import CodexLimitCore
import XCTest

final class RefreshPolicyTests: XCTestCase {
    func testDelayUntilNextStartSubtractsElapsedWork() {
        XCTAssertEqual(
            CodexLimitRefreshPolicy.delayUntilNextStart(elapsed: 12, minimumDelay: 60),
            48
        )
    }

    func testDelayUntilNextStartHonorsExtendedServerDelay() {
        XCTAssertEqual(
            CodexLimitRefreshPolicy.delayUntilNextStart(elapsed: 12, minimumDelay: 120),
            108
        )
    }

    func testDelayUntilNextStartNeverReturnsNegativeValue() {
        XCTAssertEqual(
            CodexLimitRefreshPolicy.delayUntilNextStart(elapsed: 121, minimumDelay: 120),
            0
        )
    }
}
