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
    /// KMA grid the snapshot is for, so the widget knows which grid to refresh
    /// against `getWidgetWeather`. Optional keeps older stored blobs decodable.
    var nx: Int? = nil
    var ny: Int? = nil
}

/// Shape returned by the `getWidgetWeather` Cloud Function (no `updatedAt`/grid —
/// the widget stamps those locally). Server twin: `widgetSnapshot.ts`.
struct RemoteWidgetResponse: Codable {
    let kind: WidgetWeatherSnapshot.Kind
    let line1: String
    let line2: String
    let accessibilityLabel: String
    let weatherCondition: String
    /// Home-screen widget payload (6 slots + current + alert); nil for old caches.
    let home: RemoteHome?
}

struct RemoteHome: Codable {
    struct Alert: Codable {
        let kind: HomeWidgetSnapshot.Alert.Kind
        let startText: String
        let minutesUntil: Int
    }
    struct Slot: Codable {
        let hourLabel: String
        let temperature: Int
        let precipProbability: Int
        let condition: String
    }
    let currentTemp: Int
    let currentCondition: String
    let alert: Alert?
    let slots: [Slot]
}

/// The widget fetches the server-cached snapshot for its grid instead of
/// calling KMA directly — so widget refreshes never touch the 10k/day KMA
/// quota (the scheduled Cloud Function already fetched KMA once per grid).
enum WidgetRemote {
    static let endpoint = "https://asia-northeast3-weather-79c1e.cloudfunctions.net/getWidgetWeather"

    static func fetch(nx: Int, ny: Int) async -> RemoteWidgetResponse? {
        guard var comps = URLComponents(string: endpoint) else { return nil }
        comps.queryItems = [
            URLQueryItem(name: "nx", value: "\(nx)"),
            URLQueryItem(name: "ny", value: "\(ny)"),
        ]
        guard let url = comps.url else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(RemoteWidgetResponse.self, from: data)
        } catch {
            return nil
        }
    }
}

/// Richer snapshot for the `systemMedium` **home-screen** widget: current
/// conditions + the next 6 hourly slots + optional 2h alert. Separate from the
/// lock-screen `WidgetWeatherSnapshot` (one-line) because the home widget shows
/// a full timeline. Home widgets render in full color, so the widget reuses the
/// app's face icons via `weatherCondition` raw values.
struct HomeWidgetSnapshot: Codable {
    struct Slot: Codable {
        let hourLabel: String        // "지금", "15시"
        let temperature: Int
        let precipProbability: Int   // 0...100
        let condition: String        // WeatherCondition.rawValue
    }
    struct Alert: Codable {
        enum Kind: String, Codable { case shower, rain }
        let kind: Kind
        let startText: String        // "오후 3시~4시"
        let minutesUntil: Int
    }

    let locationName: String
    let currentTemp: Int
    let currentCondition: String     // WeatherCondition.rawValue
    let alert: Alert?                // nil → calm header, else banner
    let slots: [Slot]               // up to 6
    let updatedAt: Date
    var nx: Int? = nil
    var ny: Int? = nil
}

enum WidgetSharedStore {
    static let appGroupID = "group.com.ubiweather.app"
    private static let key = "widgetWeatherSnapshot"
    private static let homeKey = "homeWidgetSnapshot"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    static func save(_ snapshot: WidgetWeatherSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    static func load() -> WidgetWeatherSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetWeatherSnapshot.self, from: data)
    }

    static func saveHome(_ snapshot: HomeWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: homeKey)
    }

    static func loadHome() -> HomeWidgetSnapshot? {
        guard let data = defaults?.data(forKey: homeKey) else { return nil }
        return try? JSONDecoder().decode(HomeWidgetSnapshot.self, from: data)
    }
}
