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

    /// Raw "YYYYMMDD" KST — the join key for the server consensus. nil on the
    /// 3-day home preview where it's never needed.
    var dateKey: String? = nil

    /// Daily 3-source consensus (F3). `nil` on days the server hasn't voted on
    /// yet — the card then renders exactly as before (KMA-only, no badge).
    var consensus: DailyConsensus? = nil

    /// The rain-ish condition to show when consensus flips a day to "rain" —
    /// keeps shower vs rain if KMA already implied one, else plain rain.
    var rainingCondition: WeatherCondition {
        condition == .shower ? .shower : .rain
    }
}

/// How much the three forecast sources agreed on a day's rain verdict, plus the
/// per-source breakdown for the tap-through detail sheet. Populated from the
/// server; the app never computes this itself.
struct DailyConsensus: Equatable {
    enum Level: String { case unanimous, majority, single }

    let level: Level
    let rainVotes: Int      // sources that said "rain" (of `voteCount`)
    let voteCount: Int      // sources that actually voted (2 or 3)
    let sources: [SourceView]

    /// Badge text for a split verdict; nil when unanimous or single-source.
    /// "3중 2" = the majority side's count (whichever way the 2 leaned).
    var badgeText: String? {
        guard level == .majority else { return nil }
        let majoritySide = max(rainVotes, voteCount - rainVotes)
        return "3중 \(majoritySide)"
    }

    /// The lone dissenter's name when exactly one source disagreed — drives the
    /// "○○만 다른 예측을 냈어요" line in the detail sheet.
    var minoritySourceName: String? {
        guard level == .majority else { return nil }
        let rainedSide = rainVotes >= voteCount - rainVotes
        let dissenters = sources.filter { $0.saysRain != rainedSide }
        return dissenters.count == 1 ? dissenters[0].displayName : nil
    }

    /// Bottom note in the detail sheet, wording lifted from the design reference.
    var sheetNote: String {
        switch level {
        case .unanimous:
            return "세 곳 모두 일치 · 신뢰도 높음"
        case .majority:
            if let name = minoritySourceName {
                return "\(name)만 다른 예측을 냈어요. 세 모델이 갈릴 땐 숨기지 않고 다수 예측과 함께 이 사실을 보여드려요."
            }
            return "세 모델이 갈렸어요. 다수 예측을 보여드립니다."
        case .single:
            return "지금은 한 출처만 응답해 합의를 잠시 멈췄어요. 남은 예보를 그대로 보여드립니다."
        }
    }

    struct SourceView: Equatable, Identifiable {
        let source: String          // "kma" | "ecmwf" | "icon"
        let saysRain: Bool
        let tempMax: Int?
        let precipProbability: Int?
        var id: String { source }

        var displayName: String {
            switch source {
            case "kma": return "기상청"
            case "ecmwf": return "ECMWF (유럽)"
            case "icon": return "ICON (독일)"
            default: return source
            }
        }
    }
}

enum HomeScreenState: Equatable {
    case loading
    case normal
    case offline(lastUpdated: String)
    case error
    case locationDenied
    case notificationPriming
}
