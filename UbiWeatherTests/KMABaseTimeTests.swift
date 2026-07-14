import XCTest
@testable import UbiWeather

final class KMABaseTimeTests: XCTestCase {
    private func kstDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal.date(from: comps)!
    }

    func testUltraSrtNcstBeforeSafeMargin() {
        // 14:09 hasn't published 14:00 yet — should fall back to 13:00.
        let bt = KMABaseTime.ultraSrtNcst(now: kstDate(2026, 7, 8, 14, 9))
        XCTAssertEqual(bt.time, "1300")
    }

    func testUltraSrtNcstAfterSafeMargin() {
        let bt = KMABaseTime.ultraSrtNcst(now: kstDate(2026, 7, 8, 14, 10))
        XCTAssertEqual(bt.time, "1400")
    }

    func testUltraSrtFcstBeforeSafeMargin() {
        let bt = KMABaseTime.ultraSrtFcst(now: kstDate(2026, 7, 8, 14, 44))
        XCTAssertEqual(bt.time, "1330")
    }

    func testUltraSrtFcstAfterSafeMargin() {
        let bt = KMABaseTime.ultraSrtFcst(now: kstDate(2026, 7, 8, 14, 45))
        XCTAssertEqual(bt.time, "1430")
    }

    func testVilageFcstMidnightBoundary() {
        // 00:09 hasn't published 02:00 yet, and 23:00 same-day doesn't exist —
        // must fall back to *yesterday's* 23:00 run.
        let bt = KMABaseTime.vilageFcst(now: kstDate(2026, 7, 8, 0, 9))
        XCTAssertEqual(bt.date, "20260707")
        XCTAssertEqual(bt.time, "2300")
    }

    func testVilageFcstMidDay() {
        let bt = KMABaseTime.vilageFcst(now: kstDate(2026, 7, 8, 15, 0))
        XCTAssertEqual(bt.date, "20260708")
        XCTAssertEqual(bt.time, "1400")
    }
}
