import Foundation

/// KMA publishes each product on a fixed schedule; calling before the safe
/// margin returns the *previous* run's data (or NODATA). All math is done in
/// KST regardless of device timezone (per spec §12.2).
enum KMABaseTime {
    private static var kst: TimeZone { TimeZone(identifier: "Asia/Seoul")! }

    private static func calendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = kst
        return cal
    }

    struct BaseDateTime {
        let date: String  // YYYYMMDD
        let time: String  // HHmm
    }

    /// `getUltraSrtNcst` — hourly (`HH00`), safe 10 minutes after the hour.
    static func ultraSrtNcst(now: Date = Date()) -> BaseDateTime {
        let cal = calendar()
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        if (comps.minute ?? 0) < 10 {
            let hourAgo = cal.date(byAdding: .hour, value: -1, to: now)!
            comps = cal.dateComponents([.year, .month, .day, .hour], from: hourAgo)
        }
        comps.minute = 0
        return format(cal, comps)
    }

    /// `getUltraSrtFcst` — half-hourly (`HH30`), safe 45 minutes after the hour.
    static func ultraSrtFcst(now: Date = Date()) -> BaseDateTime {
        let cal = calendar()
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        if (comps.minute ?? 0) < 45 {
            let hourAgo = cal.date(byAdding: .hour, value: -1, to: now)!
            comps = cal.dateComponents([.year, .month, .day, .hour], from: hourAgo)
        }
        comps.minute = 30
        return format(cal, comps)
    }

    /// `getVilageFcst` — every 3 hours starting 02:00, safe 10 minutes after.
    static func vilageFcst(now: Date = Date()) -> BaseDateTime {
        let slots = [2, 5, 8, 11, 14, 17, 20, 23]
        let cal = calendar()
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0

        var chosenHour = slots.last { $0 < hour || ($0 == hour && minute >= 10) }
        if chosenHour == nil {
            // Before 02:10 — fall back to the previous day's 23:00 run.
            let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
            var yComps = cal.dateComponents([.year, .month, .day], from: yesterday)
            yComps.hour = 23
            yComps.minute = 0
            return format(cal, yComps)
        }
        chosenHour = chosenHour ?? 23
        var result = comps
        result.hour = chosenHour
        result.minute = 0
        return format(cal, result)
    }

    private static func format(_ cal: Calendar, _ comps: DateComponents) -> BaseDateTime {
        let date = cal.date(from: comps)!
        let df = DateFormatter()
        df.calendar = cal
        df.timeZone = kst
        df.dateFormat = "yyyyMMdd"
        let tf = DateFormatter()
        tf.calendar = cal
        tf.timeZone = kst
        tf.dateFormat = "HHmm"
        return BaseDateTime(date: df.string(from: date), time: tf.string(from: date))
    }
}
