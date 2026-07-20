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

    func testRainingNowReportsOngoingAndSkipsNotification() {
        // Raining right now: the banner should say so instead of claiming a
        // countdown, and the push must not fire (user is already in the rain).
        let slots = [slot("지금", .rain), slot("15시", .sunny), slot("16시", .sunny)]
        let result = KMAParsing.evaluateAlert(slots: slots, now: kstDate(2026, 7, 8, 14, 30))!
        XCTAssertTrue(result.isOngoing)
        guard case .rain(_, let timing) = result.level else { return XCTFail("expected .rain") }
        XCTAssertEqual(timing, .ongoing)
    }

    func testCountdownMeasuredToRainStartNotNextHour() {
        // 11:56 with rain starting at 13시 is 64 minutes away — the old code
        // reported 4 (minutes to the next o'clock), contradicting the window.
        let slots = [slot("지금", .cloudy), slot("12시", .cloudy), slot("13시", .rain)]
        let result = KMAParsing.evaluateAlert(slots: slots, now: kstDate(2026, 7, 8, 11, 56))!
        guard case .rain(_, let timing) = result.level else { return XCTFail("expected .rain") }
        XCTAssertEqual(timing, .startsIn(minutes: 64))
        XCTAssertFalse(result.isOngoing)
    }

    func testWindowSpansWholeRainRunNotJustTwoSlots() {
        // All-day rain used to always read "2시간"; the window must cover the
        // full contiguous run, and stay open-ended when it runs off the forecast.
        let slots = [slot("지금", .cloudy)] + ["13시", "14시", "15시", "16시", "17시"].map { slot($0, .rain) }
        let result = KMAParsing.evaluateAlert(slots: slots, now: kstDate(2026, 7, 8, 12, 30))!
        guard case .rain(let window, _) = result.level else { return XCTFail("expected .rain") }
        XCTAssertEqual(window, "오후 1시부터 계속")
    }

    func testClosedRunReportsItsEndHour() {
        let slots = [slot("지금", .cloudy), slot("13시", .rain), slot("14시", .rain), slot("15시", .sunny)]
        let result = KMAParsing.evaluateAlert(slots: slots, now: kstDate(2026, 7, 8, 12, 30))!
        guard case .rain(let window, _) = result.level else { return XCTFail("expected .rain") }
        XCTAssertEqual(window, "오후 1시~오후 3시")
    }
}
