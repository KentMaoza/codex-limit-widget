import CodexLimitCore
import Foundation
import XCTest

final class LimitWireModelsTests: XCTestCase {
    func testMalformedAdditionalRateLimitDoesNotDiscardValidEntriesOrBaseLimit() {
        let data = Data("""
        {
          "rate_limit": {
            "primary_window": {
              "used_percent": 25,
              "limit_window_seconds": 18000
            }
          },
          "additional_rate_limits": [
            {
              "limit_name": "First",
              "rate_limit": {
                "primary_window": { "used_percent": 10 }
              }
            },
            {
              "limit_name": "Malformed"
            },
            {
              "limit_name": "Second",
              "rate_limit": {
                "primary_window": { "used_percent": 20 }
              }
            }
          ]
        }
        """.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let response: CodexUsageResponse
        do {
            response = try decoder.decode(CodexUsageResponse.self, from: data)
        } catch {
            XCTFail("Mixed optional named limits should decode lossily: \(error)")
            return
        }

        XCTAssertEqual(response.rateLimit?.primaryWindow?.remainingPercent, 75)
        XCTAssertEqual(response.additionalRateLimits?.map(\.limitName), ["First", "Second"])
        XCTAssertEqual(response.additionalRateLimits?[0].rateLimit.primaryWindow?.remainingPercent, 90)
        XCTAssertEqual(response.additionalRateLimits?[1].rateLimit.primaryWindow?.remainingPercent, 80)
    }
}
