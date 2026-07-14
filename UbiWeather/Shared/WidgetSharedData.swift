import Foundation

/// Written by `WeatherRepository` after every successful KMA refresh, read by
/// the lock-screen widget's `TimelineProvider`. The widget never re-derives
/// the alert/threshold logic itself — it only displays whatever the app
/// already computed (`AlertLevel` + `peakPrecipWindowText`'s 30% floor), so
/// the two surfaces can never disagree. Compiled into both the app and the
/// widget extension targets (see `project.yml`), shared via an App Group.
struct WidgetWeatherSnapshot: Codable {
    enum Kind: String, Codable {
        case shower, rain, calm
    }

    let kind: Kind
    let line1: String
    let line2: String
    let accessibilityLabel: String
    /// `WeatherCondition.rawValue` — picks which face icon to draw.
    let weatherCondition: String
    let updatedAt: Date
}

enum WidgetSharedStore {
    static let appGroupID = "group.com.ubiweather.app"
    private static let key = "widgetWeatherSnapshot"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    static func save(_ snapshot: WidgetWeatherSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    static func load() -> WidgetWeatherSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetWeatherSnapshot.self, from: data)
    }
}
