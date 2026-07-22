import XCTest
@testable import UbiWeather

final class AppUpdateServiceTests: XCTestCase {
    func testNumericComponentCompareNotStringCompare() {
        // "1.9.0" < "1.10.0" is the classic trap — string compare gets it wrong.
        XCTAssertTrue(AppUpdateService.isVersion("1.9.0", lessThan: "1.10.0"))
        XCTAssertFalse(AppUpdateService.isVersion("1.10.0", lessThan: "1.9.0"))
    }

    func testEqualVersionsAreNotLess() {
        XCTAssertFalse(AppUpdateService.isVersion("1.1.0", lessThan: "1.1.0"))
    }

    func testUnevenLengthsPadWithZero() {
        // "1.1" == "1.1.0", and "1.1" < "1.1.1".
        XCTAssertFalse(AppUpdateService.isVersion("1.1", lessThan: "1.1.0"))
        XCTAssertTrue(AppUpdateService.isVersion("1.1", lessThan: "1.1.1"))
    }

    func testMajorMinorPatchOrdering() {
        XCTAssertTrue(AppUpdateService.isVersion("1.1.0", lessThan: "2.0.0"))
        XCTAssertTrue(AppUpdateService.isVersion("1.1.0", lessThan: "1.2.0"))
        XCTAssertFalse(AppUpdateService.isVersion("2.0.0", lessThan: "1.9.9"))
    }
}
