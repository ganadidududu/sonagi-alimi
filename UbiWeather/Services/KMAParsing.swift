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
        /// True when it's raining *right now*. Notifications skip these — a
        /// "곧 비가 와요" push while the user is already in the rain is noise.
        let isOngoing: Bool
    }

    private static func isWet(_ slot: HourlySlot) -> Bool {
        slot.condition == .shower || slot.condition == .rain
    }

    /// Alerts when rain falls within the next ~2h (or is already falling), and
    /// reports the **whole contiguous rain run**, not just the 2-slot horizon —
    /// an all-day rain used to always read "2시간만 온다".
    static func evaluateAlert(slots: [HourlySlot], now: Date = Date()) -> AlertResult? {
        guard !slots.isEmpty else { return nil }

        // Trigger horizon: now + next 2 hourly slots.
        let horizon = min(2, slots.count - 1)
        guard let firstIdx = (0...horizon).first(where: { isWet(slots[$0]) }) else { return nil }

        // Extend through every consecutive wet slot we have forecast for.
        var lastIdx = firstIdx
        while lastIdx + 1 < slots.count, isWet(slots[lastIdx + 1]) { lastIdx += 1 }
        // Rain still falling in the final slot → we can't see its end.
        let openEnded = lastIdx == slots.count - 1

        let first = slots[firstIdx]
        let isShower = first.condition == .shower
        let startHour = hourValue(from: first.hourLabel) ?? currentHour(now)
        let endHour = (hourValue(from: slots[lastIdx].hourLabel) ?? startHour) + 1

        let isOngoing = firstIdx == 0
        let timing: AlertTiming = isOngoing
            ? .ongoing
            : .startsIn(minutes: minutesUntil(hour: startHour, now: now))

        let windowText: String
        switch (isOngoing, openEnded) {
        case (true, true):   windowText = "당분간 계속"
        case (true, false):  windowText = "지금부터 \(koreanHour(endHour))까지"
        case (false, true):  windowText = "\(koreanHour(startHour))부터 계속"
        case (false, false): windowText = "\(koreanHour(startHour))~\(koreanHour(endHour))"
        }

        let level: AlertLevel = isShower
            ? .shower(windowText: windowText, timing: timing)
            : .rain(windowText: windowText, timing: timing)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        df.timeZone = cal.timeZone
        let dedupKey = "\(isShower ? "shower" : "rain")-\(df.string(from: now))-\(startHour)"

        return AlertResult(level: level, icon: first.condition, dedupKey: dedupKey, isOngoing: isOngoing)
    }

    private static func hourValue(from label: String) -> Int? {
        Int(label.replacingOccurrences(of: "시", with: ""))
    }

    private static func currentHour(_ now: Date) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal.component(.hour, from: now)
    }

    /// Minutes from `now` to the top of `hour` — the real countdown to the rain,
    /// where we previously reported minutes to the next o'clock regardless of
    /// when the rain actually started.
    static func minutesUntil(hour: Int, now: Date) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let comps = cal.dateComponents([.hour, .minute], from: now)
        var diff = (hour - (comps.hour ?? 0)) * 60 - (comps.minute ?? 0)
        if diff <= 0 { diff += 24 * 60 }   // rain lands after midnight
        return max(diff, 1)
    }

    private static func koreanHour(_ hour24: Int) -> String {
        let h = ((hour24 % 24) + 24) % 24
        let period = h < 12 ? "오전" : "오후"
        let hour12 = h % 12 == 0 ? 12 : h % 12
        return "\(period) \(hour12)시"
    }
}
