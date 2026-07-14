import XCTest
@testable import UbiWeather

final class KMAModelsTests: XCTestCase {
    func testDecodesNcstResponse() throws {
        let json = """
        {
          "response": {
            "header": { "resultCode": "00", "resultMsg": "NORMAL_SERVICE" },
            "body": {
              "dataType": "JSON",
              "items": {
                "item": [
                  { "baseDate": "20260708", "baseTime": "1400", "category": "T1H", "obsrValue": "22", "nx": 60, "ny": 127 },
                  { "baseDate": "20260708", "baseTime": "1400", "category": "PTY", "obsrValue": "0", "nx": 60, "ny": 127 }
                ]
              },
              "pageNo": 1, "numOfRows": 10, "totalCount": 2
            }
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(KMAResponse.self, from: json)
        XCTAssertEqual(decoded.response.header.resultCode, "00")
        let items = decoded.response.body?.items?.item ?? []
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.doubleValue, 22)
    }

    func testResultCodeMapsToFriendlyMessage() {
        XCTAssertNil(KMAResultCode.message(for: "00"))
        XCTAssertNotNil(KMAResultCode.message(for: "03"))
        XCTAssertNotNil(KMAResultCode.message(for: "22"))
    }

    func testWeatherConditionPrefersPrecipitationOverSky() {
        XCTAssertEqual(weatherCondition(pty: 4, sky: 1), .shower)
        XCTAssertEqual(weatherCondition(pty: 0, sky: 1), .sunny)
        XCTAssertEqual(weatherCondition(pty: 0, sky: 3), .partly)
        XCTAssertEqual(weatherCondition(pty: 1, sky: 4), .rain)
    }

    func testIsNoPrecip() {
        XCTAssertTrue(isNoPrecip(rn1Raw: "-"))
        XCTAssertTrue(isNoPrecip(rn1Raw: "0"))
        XCTAssertTrue(isNoPrecip(rn1Raw: nil))
        XCTAssertFalse(isNoPrecip(rn1Raw: "1.5"))
    }
}
