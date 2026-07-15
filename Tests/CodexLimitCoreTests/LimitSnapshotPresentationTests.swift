import CodexLimitCore
import Foundation
import XCTest

final class LimitSnapshotPresentationTests: XCTestCase {
    func testDataAndStalenessFollowSuccessfulUsageState() {
        let successfulWithoutOptionalMetrics = snapshot(windowCount: 0)
        let initialFailure = snapshot(windowCount: 0, generatedAt: Date(timeIntervalSince1970: 0), errorMessage: "Offline")
        let stale = snapshot(windowCount: 2, errorMessage: "Offline")
        let recovered = snapshot(windowCount: 4)

        XCTAssertFalse(LimitSnapshot.notChecked.hasData)
        XCTAssertFalse(LimitSnapshot.notChecked.isStale)
        XCTAssertTrue(successfulWithoutOptionalMetrics.hasData)
        XCTAssertFalse(successfulWithoutOptionalMetrics.isStale)
        XCTAssertFalse(initialFailure.hasData)
        XCTAssertFalse(initialFailure.isStale)
        XCTAssertTrue(stale.hasData)
        XCTAssertTrue(stale.isStale)
        XCTAssertTrue(recovered.hasData)
        XCTAssertFalse(recovered.isStale)
    }

    func testStatusLevelUsesErrorPrecedenceAndInclusiveThresholdsAcrossAllWindows() {
        let initialFailure = snapshot(windowCount: 0, generatedAt: Date(timeIntervalSince1970: 0), errorMessage: "Offline")
        let staleCriticalData = snapshot(windowCount: 2, remaining: [100, 0], errorMessage: "Offline")
        let criticalNamedLimit = snapshot(windowCount: 4, remaining: [100, 100, 100, 15])
        let warningNamedLimit = snapshot(windowCount: 6, remaining: [100, 100, 100, 100, 16, 30])
        let normal = snapshot(windowCount: 6, remaining: Array(repeating: 31, count: 6))

        XCTAssertEqual(LimitSnapshot.notChecked.statusLevel, .unavailable)
        XCTAssertEqual(initialFailure.statusLevel, .error)
        XCTAssertEqual(initialFailure.statusTitle, "Check Codex login")
        XCTAssertEqual(staleCriticalData.statusLevel, .error)
        XCTAssertEqual(criticalNamedLimit.statusLevel, .critical)
        XCTAssertEqual(warningNamedLimit.statusLevel, .warning)
        XCTAssertEqual(normal.statusLevel, .normal)
    }

    func testUnknownBalanceAndPercentagesUseEmDash() {
        let unknown = snapshot(windowCount: 2, remaining: [nil, nil])

        XCTAssertEqual(unknown.balanceValue, "—")
        XCTAssertEqual(unknown.compactBalance, "—")
        XCTAssertEqual(unknown.summaryLine, "5h — / W — / —")
        XCTAssertFalse(unknown.summaryLine.contains("-"))
        XCTAssertFalse(unknown.summaryLine.contains("0"))
    }

    func testBaseWindowAccessorsRemainExactWithNamedWindows() {
        let snapshot = snapshot(windowCount: 6)

        XCTAssertEqual(snapshot.fiveHourWindow?.id, "five-hour")
        XCTAssertEqual(snapshot.weeklyWindow?.id, "weekly")
    }

    private func snapshot(
        windowCount: Int,
        remaining: [Int?] = [],
        generatedAt: Date = Date(timeIntervalSince1970: 1_800_000_000),
        errorMessage: String? = nil
    ) -> LimitSnapshot {
        LimitSnapshot(
            generatedAt: generatedAt,
            lastAttemptAt: Date(timeIntervalSince1970: 1_800_000_060),
            planLabel: "Codex",
            availableResetCount: 0,
            windows: (0..<windowCount).map { index in
                let remainingPercent = index < remaining.count ? remaining[index] : 100
                return LimitWindowSnapshot(
                    id: windowID(at: index),
                    kind: index == 0 ? .fiveHour : index == 1 ? .weekly : .generic,
                    title: "Window \(index)",
                    usedPercent: remainingPercent.map { 100 - $0 },
                    remainingPercent: remainingPercent,
                    resetAfterSeconds: nil,
                    resetAt: nil
                )
            },
            errorMessage: errorMessage
        )
    }

    private func windowID(at index: Int) -> String {
        switch index {
        case 0: "five-hour"
        case 1: "weekly"
        default: "additional-\(index - 2)"
        }
    }
}
