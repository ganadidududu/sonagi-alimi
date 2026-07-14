import XCTest
@testable import UbiWeather

final class NotificationPreferencesTests: XCTestCase {
    private func kstDate(_ h: Int, _ min: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 8; comps.hour = h; comps.minute = min
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal.date(from: comps)!
    }

    func testDndWindowCoversNightHours() {
        XCTAssertTrue(NotificationPreferences.isWithinDndWindow(now: kstDate(23)))
        XCTAssertTrue(NotificationPreferences.isWithinDndWindow(now: kstDate(2)))
        XCTAssertTrue(NotificationPreferences.isWithinDndWindow(now: kstDate(6, 59)))
    }

    func testDndWindowExcludesDaytime() {
        XCTAssertFalse(NotificationPreferences.isWithinDndWindow(now: kstDate(7)))
        XCTAssertFalse(NotificationPreferences.isWithinDndWindow(now: kstDate(14)))
        XCTAssertFalse(NotificationPreferences.isWithinDndWindow(now: kstDate(21, 59)))
    }
}
