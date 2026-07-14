import Foundation

/// Pure `getUltraSrtFcst` parsing + alert-window evaluation, with no
/// `@MainActor`/view-model dependency. Shared by `WeatherRepository` (foreground
/// refresh) and `BackgroundRefreshManager` (BGTaskScheduler check), so the
/// "is a shower/rain coming in the next 2h" logic only lives in one place.
enum KMAParsing {
    static func parseHourlySlots(_ items: [KMAItem]) -> [HourlySlot] {
        var byTime: [String: [String: KMAItem]] = [:]  // "yyyyMMddHHmm" -> category -> item
        for item in items {
            guard let date = item.fcstDate, let time = item.fcstTime else { continue }
            byTime[date + time, default: [:]][item.category] = item
        }

        let orderedKeys = byTime.keys.sorted().prefix(7)
        var slots: [HourlySlot] = []
        for (index, key) in orderedKeys.enumerated() {
            guard let categories = byTime[key],
                  let temp = categories["T1H"]?.intValue,
                  let pty = categories["PTY"]?.intValue else { continue }
            let sky = categories["SKY"]?.intValue
            let pop = categories["POP"]?.intValue ?? 0
            let condition = weatherCondition(pty: pty, sky: sky)
            let label = conditionLabel(pty: pty, sky: sky)
            let hour = Int(key.suffix(4).prefix(2)) ?? 0
            let hourLabel = index == 0 ? "지금" : "\(hour)시"
            slots.append(HourlySlot(hourLabel: hourLabel, temperature: temp, precipProbability: pop, condition: condition, conditionLabel: label))
        }
        return slots
    }

    struct AlertResult {
        let level: AlertLevel
        let icon: WeatherCondition
        /// Stable per rain-event key (date + start hour) — used to dedup
        /// notifications so the same event doesn't re-fire every refresh.
        let dedupKey: String
    }

    /// `slots[0]` is "now"; only the next ~2h (slots 1-2, since each covers ~1h) count as "upcoming".
    static func evaluateAlert(slots: [HourlySlot], now: Date = Date()) -> AlertResult? {
        let upcoming = Array(slots.dropFirst().prefix(2))
        guard let firstRain = upcoming.first(where: { $0.condition == .shower || $0.condition == .rain }) else {
            return nil
        }

        let isShower = firstRain.condition == .shower
        let startHour = hourValue(from: firstRain.hourLabel) ?? currentHour(now)
        let endHour = startHour + upcoming.filter { $0.condition == .shower || $0.condition == .rain }.count
        let windowText = koreanHourRange(startHour: startHour, endHour: endHour)
        let minutesUntil = minutesUntilNextHour(now: now)

        let level: AlertLevel = isShower
            ? .shower(windowText: windowText, minutesUntil: minutesUntil)
            : .rain(windowText: windowText, minutesUntil: minutesUntil)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        df.timeZone = cal.timeZone
        let dedupKey = "\(isShower ? "shower" : "rain")-\(df.string(from: now))-\(startHour)"

        return AlertResult(level: level, icon: firstRain.condition, dedupKey: dedupKey)
    }

    private static func hourValue(from label: String) -> Int? {
        Int(label.replacingOccurrences(of: "시", with: ""))
    }

    private static func currentHour(_ now: Date) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal.component(.hour, from: now)
    }

    private static func minutesUntilNextHour(now: Date) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let minute = cal.component(.minute, from: now)
        return max(60 - minute, 1)
    }

    private static func koreanHourRange(startHour: Int, endHour: Int) -> String {
        "\(koreanHour(startHour))~\(koreanHour(endHour))"
    }

    private static func koreanHour(_ hour24: Int) -> String {
        let h = ((hour24 % 24) + 24) % 24
        let period = h < 12 ? "오전" : "오후"
        let hour12 = h % 12 == 0 ? 12 : h % 12
        return "\(period) \(hour12)시"
    }
}
