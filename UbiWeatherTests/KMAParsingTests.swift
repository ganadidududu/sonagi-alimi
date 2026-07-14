import XCTest
@testable import UbiWeather

final class KMAParsingTests: XCTestCase {
    private func kstDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal.date(from: comps)!
    }

    private func slot(_ hourLabel: String, _ condition: WeatherCondition) -> HourlySlot {
        HourlySlot(hourLabel: hourLabel, temperature: 20, precipProbability: 50, condition: condition, conditionLabel: "")
    }

    func testNoAlertWhenNextTwoSlotsAreDry() {
        let slots = [slot("지금", .cloudy), slot("15시", .cloudy), slot("16시", .sunny)]
        XCTAssertNil(KMAParsing.evaluateAlert(slots: slots, now: kstDate(2026, 7, 8, 14, 30)))
    }

    func testShowerDetectedInUpcomingWindow() {
        let slots = [slot("지금", .cloudy), slot("15시", .shower), slot("16시", .shower)]
        let result = KMAParsing.evaluateAlert(slots: slots, now: kstDate(2026, 7, 8, 14, 30))
        XCTAssertNotNil(result)
        if case .shower = result!.level {} else { XCTFail("expected .shower, got \(result!.level)") }
        XCTAssertEqual(result!.icon, .shower)
    }

    func testRainTakesRainBranchNotShower() {
        let slots = [slot("지금", .cloudy), slot("15시", .rain), slot("16시", .cloudy)]
        let result = KMAParsing.evaluateAlert(slots: slots, now: kstDate(2026, 7, 8, 14, 30))
        if case .rain = result!.level {} else { XCTFail("expected .rain, got \(result!.level)") }
    }

    func testDedupKeyStableForSameEventDifferentMinute() {
        let slots = [slot("지금", .cloudy), slot("15시", .shower)]
        let a = KMAParsing.evaluateAlert(slots: slots, now: kstDate(2026, 7, 8, 14, 5))!
        let b = KMAParsing.evaluateAlert(slots: slots, now: kstDate(2026, 7, 8, 14, 55))!
        XCTAssertEqual(a.dedupKey, b.dedupKey)
    }

    func testDedupKeyDiffersByDay() {
        let slots = [slot("지금", .cloudy), slot("15시", .shower)]
        let day1 = KMAParsing.evaluateAlert(slots: slots, now: kstDate(2026, 7, 8, 14, 30))!
        let day2 = KMAParsing.evaluateAlert(slots: slots, now: kstDate(2026, 7, 9, 14, 30))!
        XCTAssertNotEqual(day1.dedupKey, day2.dedupKey)
    }

    func testOnlyFirstSlotIsExcludedFromWindow() {
        // "지금" (now) having shower shouldn't trigger — only *upcoming* slots count.
        let slots = [slot("지금", .shower), slot("15시", .sunny), slot("16시", .sunny)]
        XCTAssertNil(KMAParsing.evaluateAlert(slots: slots, now: kstDate(2026, 7, 8, 14, 30)))
    }
}
