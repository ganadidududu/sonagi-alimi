import Foundation

/// Maps to KMA `PTY`/`SKY` categories. `shower` (PTY=4) is the brand's signature state.
enum WeatherCondition: String {
    case sunny, partly, cloudy, rain, shower

    var sfSymbol: String {
        switch self {
        case .sunny: return "sun.max.fill"
        case .partly: return "cloud.sun.fill"
        case .cloudy: return "cloud.fill"
        case .rain: return "cloud.rain.fill"
        case .shower: return "cloud.sun.rain.fill"
        }
    }

    var label: String {
        switch self {
        case .sunny: return "맑음"
        case .partly: return "구름 조금"
        case .cloudy: return "흐림"
        case .rain: return "비"
        case .shower: return "소나기"
        }
    }
}

/// Home screen "killer feature" — the 0~2h precipitation alert banner.
/// When the rain happens relative to now. Split out because "N분 뒤 시작" is
/// nonsense while it's already raining — the banner said that for every
/// all-day rain, and the minutes were counted to the next o'clock rather than
/// to the actual start.
enum AlertTiming: Equatable {
    case ongoing                 // 이미 내리는 중
    case startsIn(minutes: Int)  // 시작까지 남은 시간

    /// "35분" / "1시간" — hours read better than "약 64분 뒤".
    var shortText: String {
        switch self {
        case .ongoing: return ""
        case .startsIn(let m):
            return m < 60 ? "\(m)분" : "\(Int((Double(m) / 60).rounded()))시간"
        }
    }

    /// Widget payload keeps a plain Int; 0 encodes "already raining".
    var minutesOrZero: Int {
        switch self {
        case .ongoing: return 0
        case .startsIn(let m): return m
        }
    }
}

enum AlertLevel {
    case shower(windowText: String, timing: AlertTiming)
    case rain(windowText: String, timing: AlertTiming)
    case none

    var badgeText: String? {
        switch self {
        case .shower: return "🌦 소나기 예정"
        case .rain: return "🌧 비 예정"
        case .none: return nil
        }
    }
}

struct HourlySlot: Identifiable {
    let id = UUID()
    let hourLabel: String       // "지금", "15시" ...
    let temperature: Int
    let precipProbability: Int
    let condition: WeatherCondition
    let conditionLabel: String
    var isHighlighted: Bool { condition == .shower }
}

struct DailySummary: Identifiable {
    let id = UUID()
    let dayLabel: String        // "오늘" / "내일" / "모레" / weekday
    let dateLabel: String?      // "7/8" (nil in the 3-day home preview)
    let condition: WeatherCondition
    let conditionLabel: String
    let precipProbability: Int
    let low: Int
    let high: Int
    var isToday: Bool = false
}

enum HomeScreenState: Equatable {
    case loading
    case normal
    case offline(lastUpdated: String)
    case error
    case locationDenied
    case notificationPriming
}
