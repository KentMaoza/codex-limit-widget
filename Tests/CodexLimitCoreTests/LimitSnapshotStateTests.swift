import CodexLimitCore
import Foundation
import XCTest

final class LimitSnapshotStateTests: XCTestCase {
    func testLegacySnapshotWithoutLastAttemptStillDecodes() throws {
        let snapshot = try JSONDecoder().decode(LimitSnapshot.self, from: Data("""
        {
          "generatedAt": 100,
          "planLabel": "Codex",
          "availableResetCount": 2,
          "windows": [],
          "errorMessage": null
        }
        """.utf8))

        XCTAssertNil(snapshot.lastAttemptAt)
        XCTAssertEqual(snapshot.generatedAt, Date(timeIntervalSinceReferenceDate: 100))
    }

    func testLastAttemptRoundTrips() throws {
        let snapshot = LimitSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            lastAttemptAt: Date(timeIntervalSince1970: 1_800_000_060),
            planLabel: "Codex",
            availableResetCount: 1,
            windows: [],
            errorMessage: nil
        )

        let decoded = try JSONDecoder().decode(LimitSnapshot.self, from: JSONEncoder().encode(snapshot))

        XCTAssertEqual(decoded, snapshot)
    }
}
