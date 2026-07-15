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

    func testResetCountAvailabilityRoundTripsAndLegacyDefaults() throws {
        let knownZero = LimitSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            planLabel: "Codex",
            availableResetCount: 0,
            windows: [],
            errorMessage: nil
        )
        let unavailable = try decode("""
        {
          "generatedAt": 100,
          "planLabel": "Codex",
          "availableResetCount": 0,
          "isResetCountAvailable": false,
          "windows": [],
          "errorMessage": null
        }
        """)
        let legacySuccessfulZero = try decode("""
        {
          "generatedAt": 100,
          "planLabel": "Codex",
          "availableResetCount": 0,
          "windows": [],
          "errorMessage": null
        }
        """)
        let legacyPartialFailureZero = try decode("""
        {
          "generatedAt": 100,
          "planLabel": "Codex",
          "availableResetCount": 0,
          "windows": [],
          "errorMessage": "Reset data unavailable"
        }
        """)
        let legacyPartialFailurePositive = try decode("""
        {
          "generatedAt": 100,
          "planLabel": "Codex",
          "availableResetCount": 2,
          "windows": [],
          "errorMessage": "Reset data unavailable"
        }
        """)
        let legacyNotChecked = try decode("""
        {
          "generatedAt": -978307200,
          "planLabel": "Codex",
          "availableResetCount": 0,
          "windows": [],
          "errorMessage": null
        }
        """)

        XCTAssertEqual(try encodedObject(knownZero)["isResetCountAvailable"] as? Bool, true)
        XCTAssertEqual(try encodedObject(unavailable)["isResetCountAvailable"] as? Bool, false)
        XCTAssertEqual(try roundTrip(knownZero).balanceValue, "0")
        XCTAssertEqual(try roundTrip(unavailable).balanceValue, "—")
        XCTAssertEqual(legacySuccessfulZero.balanceValue, "0")
        XCTAssertEqual(legacySuccessfulZero.compactBalance, "0R")
        XCTAssertEqual(legacyPartialFailureZero.balanceValue, "—")
        XCTAssertEqual(legacyPartialFailureZero.compactBalance, "—")
        XCTAssertEqual(legacyPartialFailurePositive.balanceValue, "2")
        XCTAssertEqual(legacyNotChecked.balanceValue, "—")
    }

    private func decode(_ json: String) throws -> LimitSnapshot {
        try JSONDecoder().decode(LimitSnapshot.self, from: Data(json.utf8))
    }

    private func encodedObject(_ snapshot: LimitSnapshot) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
    }

    private func roundTrip(_ snapshot: LimitSnapshot) throws -> LimitSnapshot {
        try JSONDecoder().decode(LimitSnapshot.self, from: JSONEncoder().encode(snapshot))
    }
}
