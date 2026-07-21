import Foundation

/// Persists the last successfully-rendered forecast so a KMA outage shows the
/// user their most recent weather ("14:32 기준") instead of a blank error
/// screen. The KMA public API drops out fairly often; before this, any hiccup
/// wiped the home screen even though good data was sitting in memory minutes ago.
///
/// A display-ready snapshot (not raw KMA items) so restoring is a straight
/// assignment with no re-parsing. Consensus is intentionally omitted — it's a
/// server-cached extra, not part of the core "current weather" the user needs
/// offline.
enum ForecastCache {
    private static let key = "forecast.cache.v1"
    private static let defaults = UserDefaults.standard

    struct Snapshot: Codable {
        var savedAt: Date
        var locationName: String

        // Current conditions card
        var currentTemperature: Int
        var currentSummaryLabel: String
        var currentIcon: String        // WeatherCondition rawValue
        var humidityPercent: Int
        var windSpeed: String
        var precipProbability: Int

        // Alert banner (nil = no active alert)
        var alert: Alert?
        var bannerIcon: String

        var hourly: [Hourly]
        var threeDay: [Daily]
        var weekly: [Daily]
        var peakPrecipWindowText: String

        struct Alert: Codable {
            var isShower: Bool
            var windowText: String
            var timingMinutes: Int?    // nil = ongoing
        }
        struct Hourly: Codable {
            var hourLabel: String
            var temperature: Int
            var precipProbability: Int
            var condition: String
            var conditionLabel: String
        }
        struct Daily: Codable {
            var dayLabel: String
            var dateLabel: String?
            var condition: String
            var conditionLabel: String
            var precipProbability: Int
            var low: Int
            var high: Int
            var isToday: Bool
        }
    }

    static func save(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> Snapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    /// "14:32" in KST — the "○○ 기준" label on the offline strip.
    static func timeLabel(for date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        df.timeZone = TimeZone(identifier: "Asia/Seoul")
        return df.string(from: date)
    }
}
