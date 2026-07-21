import Foundation
import Observation

/// Holds Home-screen state. Populated with the exact sample values from the
/// design reference (`design_handoff_ubi_weather/ubi-weather-reference.html`)
/// so the UI can be visually diffed 1:1 before real KMA data is wired in.
@MainActor
@Observable
final class WeatherViewModel {
    var selectedTab: UbiTab = .home
    var screenState: HomeScreenState = .normal
    var accent: AlertAccent = .amber
    var rainAnimationEnabled: Bool = true

    var locationName: String = "마포구 서교동"
    var lastUpdatedLabel: String = "방금 업데이트"
    var offlineLastUpdated: String = "14:32"

    // Alert banner (killer feature)
    var alertLevel: AlertLevel = .shower(windowText: "오후 3시~오후 5시", timing: .startsIn(minutes: 13))
    var bannerIcon: WeatherCondition = .shower

    // Current weather card
    var currentTemperature: Int = 22
    var currentSummaryLabel: String = "흐림 · 곧 비 · 체감 21°"
    var currentIcon: WeatherCondition = .cloudy
    var humidityPercent: Int = 78
    var windSpeed: String = "2.4㎧"
    var precipProbability: Int = 80

    var hourly: [HourlySlot] = [
        HourlySlot(hourLabel: "지금", temperature: 22, precipProbability: 60, condition: .cloudy, conditionLabel: "흐림"),
        HourlySlot(hourLabel: "15시", temperature: 21, precipProbability: 80, condition: .shower, conditionLabel: "소나기"),
        HourlySlot(hourLabel: "16시", temperature: 20, precipProbability: 75, condition: .shower, conditionLabel: "소나기"),
        HourlySlot(hourLabel: "17시", temperature: 20, precipProbability: 55, condition: .rain, conditionLabel: "약한 비"),
        HourlySlot(hourLabel: "18시", temperature: 21, precipProbability: 30, condition: .cloudy, conditionLabel: "흐림"),
        HourlySlot(hourLabel: "19시", temperature: 22, precipProbability: 10, condition: .partly, conditionLabel: "구름 조금"),
        HourlySlot(hourLabel: "20시", temperature: 21, precipProbability: 5, condition: .partly, conditionLabel: "대체로 맑음"),
    ]

    var threeDay: [DailySummary] = [
        DailySummary(dayLabel: "오늘", dateLabel: nil, condition: .shower, conditionLabel: "소나기", precipProbability: 80, low: 19, high: 23, isToday: true),
        DailySummary(dayLabel: "내일", dateLabel: nil, condition: .cloudy, conditionLabel: "흐림", precipProbability: 30, low: 18, high: 24),
        DailySummary(dayLabel: "모레", dateLabel: nil, condition: .sunny, conditionLabel: "맑음", precipProbability: 0, low: 20, high: 27),
    ]

    // Hourly tab summary banner
    var peakPrecipWindowText: String = "15시~16시 강수확률이 가장 높아요 (80%)"

    // Daily tab (7-day)
    var weekly: [DailySummary] = [
        DailySummary(dayLabel: "오늘", dateLabel: "7/8", condition: .shower, conditionLabel: "소나기", precipProbability: 80, low: 19, high: 23, isToday: true),
        DailySummary(dayLabel: "내일", dateLabel: "7/9", condition: .cloudy, conditionLabel: "흐림", precipProbability: 30, low: 18, high: 24),
        DailySummary(dayLabel: "모레", dateLabel: "7/10", condition: .sunny, conditionLabel: "맑음", precipProbability: 0, low: 20, high: 27),
        DailySummary(dayLabel: "금", dateLabel: "7/11", condition: .sunny, conditionLabel: "맑음", precipProbability: 5, low: 21, high: 29),
        DailySummary(dayLabel: "토", dateLabel: "7/12", condition: .partly, conditionLabel: "구름 조금", precipProbability: 20, low: 22, high: 30),
        DailySummary(dayLabel: "일", dateLabel: "7/13", condition: .rain, conditionLabel: "비", precipProbability: 65, low: 21, high: 26),
        DailySummary(dayLabel: "월", dateLabel: "7/14", condition: .shower, conditionLabel: "소나기", precipProbability: 70, low: 20, high: 25),
    ]

    /// Header pill above the daily list. `nil` until the server consensus has
    /// been merged in (fresh grid, offline) — the pill simply doesn't show, and
    /// the list renders as the KMA-only forecast it already was.
    var consensusSummary: ConsensusSummary? {
        let voted = weekly.compactMap(\.consensus)
        guard !voted.isEmpty else { return nil }
        // Any degraded day means the whole vote is running on a fallback.
        return voted.contains { $0.level == .single } ? .fallback : .active
    }

    enum ConsensusSummary {
        case active    // 3 sources voting
        case fallback  // one source down, consensus paused

        var pillText: String {
            switch self {
            case .active: return "기상청·ECMWF·ICON 합의"
            case .fallback: return "합의 일시 중단 · 기상청 단독"
            }
        }
        var pillIcon: String { self == .active ? "⚖️" : "⚠️" }
    }

    // Radar tab
    enum RadarLoadState: Equatable { case idle, loading, loaded, error(String) }
    var radarLoadState: RadarLoadState = .idle
    var radarFrames: [RadarFrame] = []
    var radarFrameIndex: Int = 0

    var radarCurrentFrame: RadarFrame? {
        radarFrames.indices.contains(radarFrameIndex) ? radarFrames[radarFrameIndex] : nil
    }
    var radarTimeLabel: String { radarCurrentFrame?.timeLabel ?? "--:--" }
    var radarProgress: Double {
        guard radarFrames.count > 1 else { return 0 }
        return Double(radarFrameIndex) / Double(radarFrames.count - 1)
    }

    // Settings — region
    var savedRegions: [String] = ["강남구 역삼동", "부산 해운대구"]

    // Settings — notifications. Mirrored into `NotificationPreferences` (UserDefaults,
    // for the local BGAppRefreshTask path) and, once configured, into Firestore
    // (for the Cloud Function path) — see `PushRegistrationService`.
    var notifMasterOn: Bool { didSet { NotificationPreferences.masterOn = notifMasterOn; syncPreferencesToPush() } }
    var notifShowerOn: Bool { didSet { NotificationPreferences.showerOn = notifShowerOn; syncPreferencesToPush() } }
    var notifRainOn: Bool { didSet { NotificationPreferences.rainOn = notifRainOn; syncPreferencesToPush() } }
    var notifDndOn: Bool { didSet { NotificationPreferences.dndOn = notifDndOn; syncPreferencesToPush() } }
    var briefingOn: Bool { didSet { NotificationPreferences.briefingOn = briefingOn; syncPreferencesToPush() } }
    var briefingHour: Int { didSet { NotificationPreferences.briefingHour = briefingHour; syncPreferencesToPush() } }
    var briefingMinute: Int { didSet { NotificationPreferences.briefingMinute = briefingMinute; syncPreferencesToPush() } }
    var darkModeOn: Bool = false

    /// "오전 7:30" for the settings row.
    var briefingTimeLabel: String {
        let period = briefingHour < 12 ? "오전" : "오후"
        let hour12 = briefingHour % 12 == 0 ? 12 : briefingHour % 12
        return String(format: "%@ %d:%02d", period, hour12, briefingMinute)
    }

    init() {
        notifMasterOn = NotificationPreferences.masterOn
        notifShowerOn = NotificationPreferences.showerOn
        notifRainOn = NotificationPreferences.rainOn
        notifDndOn = NotificationPreferences.dndOn
        briefingOn = NotificationPreferences.briefingOn
        briefingHour = NotificationPreferences.briefingHour
        briefingMinute = NotificationPreferences.briefingMinute
    }

    private func syncPreferencesToPush() {
        PushRegistrationService.shared.updatePreferences(
            masterOn: notifMasterOn, showerOn: notifShowerOn, rainOn: notifRainOn, dndOn: notifDndOn,
            briefingOn: briefingOn, briefingHour: briefingHour, briefingMinute: briefingMinute
        )
    }

    func goToHourly() {
        selectedTab = .hourly
    }
}
