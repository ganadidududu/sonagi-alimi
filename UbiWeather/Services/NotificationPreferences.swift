import Foundation

/// UserDefaults-backed settings, readable from contexts that don't have a
/// live `WeatherViewModel` — namely the `BGAppRefreshTask` handler, which may
/// run after the app process was fully terminated and relaunched headlessly.
enum NotificationPreferences {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let masterOn = "notif.masterOn"
        static let showerOn = "notif.showerOn"
        static let rainOn = "notif.rainOn"
        static let dndOn = "notif.dndOn"
        static let lastNotifiedKey = "notif.lastNotifiedKey"
        static let lastGridNx = "notif.lastGridNx"
        static let lastGridNy = "notif.lastGridNy"
    }

    static var masterOn: Bool {
        get { defaults.object(forKey: Key.masterOn) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.masterOn) }
    }
    static var showerOn: Bool {
        get { defaults.object(forKey: Key.showerOn) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.showerOn) }
    }
    static var rainOn: Bool {
        get { defaults.object(forKey: Key.rainOn) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.rainOn) }
    }
    static var dndOn: Bool {
        get { defaults.object(forKey: Key.dndOn) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.dndOn) }
    }

    static var lastNotifiedKey: String? {
        get { defaults.string(forKey: Key.lastNotifiedKey) }
        set { defaults.set(newValue, forKey: Key.lastNotifiedKey) }
    }

    static func setLastGrid(nx: Int, ny: Int) {
        defaults.set(nx, forKey: Key.lastGridNx)
        defaults.set(ny, forKey: Key.lastGridNy)
    }

    /// `nil` until the app has completed at least one foreground location fix.
    static var lastGrid: (nx: Int, ny: Int)? {
        guard defaults.object(forKey: Key.lastGridNx) != nil else { return nil }
        return (defaults.integer(forKey: Key.lastGridNx), defaults.integer(forKey: Key.lastGridNy))
    }

    /// 22:00–07:00 KST, matching the Settings screen's "방해금지 시간" copy.
    static func isWithinDndWindow(now: Date = Date()) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let hour = cal.component(.hour, from: now)
        return hour >= 22 || hour < 7
    }
}
