import XCTest
@testable import UbiWeather

final class ForecastCacheTests: XCTestCase {
    private func sample(savedAt: Date) -> ForecastCache.Snapshot {
        ForecastCache.Snapshot(
            savedAt: savedAt, locationName: "마포구 서교동",
            currentTemperature: 22, currentSummaryLabel: "흐림 · 곧 비", currentIcon: "cloudy",
            humidityPercent: 78, windSpeed: "2.4㎧", precipProbability: 80,
            alert: .init(isShower: true, windowText: "오후 3시~오후 5시", timingMinutes: 13),
            bannerIcon: "shower",
            hourly: [.init(hourLabel: "지금", temperature: 22, precipProbability: 60, condition: "cloudy", conditionLabel: "흐림")],
            threeDay: [.init(dayLabel: "오늘", dateLabel: nil, condition: "shower", conditionLabel: "소나기", precipProbability: 80, low: 19, high: 23, isToday: true)],
            weekly: [.init(dayLabel: "오늘", dateLabel: "7/8", condition: "shower", conditionLabel: "소나기", precipProbability: 80, low: 19, high: 23, isToday: true)],
            peakPrecipWindowText: "15시~16시 강수확률이 가장 높아요 (80%)"
        )
    }

    func testSaveLoadRoundTrip() {
        let now = Date(timeIntervalSince1970: 1_784_600_000)
        ForecastCache.save(sample(savedAt: now))
        let loaded = ForecastCache.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.locationName, "마포구 서교동")
        XCTAssertEqual(loaded?.currentTemperature, 22)
        XCTAssertEqual(loaded?.alert?.windowText, "오후 3시~오후 5시")
        XCTAssertEqual(loaded?.alert?.timingMinutes, 13)
        XCTAssertEqual(loaded?.hourly.count, 1)
        XCTAssertEqual(loaded?.weekly.first?.dateLabel, "7/8")
    }

    func testOngoingAlertRoundTripsAsNilMinutes() {
        // Ongoing rain has no countdown; the cache encodes that as nil, not 0,
        // so restoring reproduces `.ongoing` rather than a fake "0분 뒤".
        var s = sample(savedAt: Date(timeIntervalSince1970: 1_784_600_000))
        s.alert = .init(isShower: false, windowText: "지금부터 오후 4시까지", timingMinutes: nil)
        ForecastCache.save(s)
        XCTAssertNil(ForecastCache.load()?.alert?.timingMinutes)
    }

    func testTimeLabelIsKST() {
        // 1784600000 == 2026-07-21 02:13 UTC == 11:13 KST
        let d = Date(timeIntervalSince1970: 1_784_600_000)
        XCTAssertEqual(ForecastCache.timeLabel(for: d), "11:13")
    }
}
