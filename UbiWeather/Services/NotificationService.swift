import UserNotifications

/// Posts the shower/rain alert as a local notification. There is no backend
/// in this app, so this is triggered either right after a foreground refresh
/// or from `BackgroundRefreshManager`'s BGAppRefreshTask — never a real push.
enum NotificationService {
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Evaluates preferences + dedup + DND, and posts only if everything clears.
    /// Safe to call after every refresh (foreground or background) — most
    /// calls will be no-ops because nothing changed since the last check.
    static func postIfNeeded(_ alert: KMAParsing.AlertResult) async {
        guard NotificationPreferences.masterOn else { return }
        guard alert.dedupKey != NotificationPreferences.lastNotifiedKey else { return }
        guard !NotificationPreferences.isWithinDndWindow() else { return }

        let isShower: Bool
        switch alert.level {
        case .shower: isShower = true
        case .rain: isShower = false
        case .none: return
        }
        if isShower, !NotificationPreferences.showerOn { return }
        if !isShower, !NotificationPreferences.rainOn { return }

        guard await authorizationStatus() == .authorized else { return }

        let content = UNMutableNotificationContent()
        switch alert.level {
        case .shower(let window, let minutes):
            content.title = "🌦 소나기 알림"
            content.body = "\(window)에 소나기가 지나가요. 약 \(minutes)분 뒤 시작 · 우산을 꼭 챙기세요 ☂️"
        case .rain(let window, let minutes):
            content.title = "🌧 비 알림"
            content.body = "\(window)에 비가 내려요. 약 \(minutes)분 뒤 시작 · 우산을 챙기세요 ☂️"
        case .none:
            return
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: alert.dedupKey,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
        NotificationPreferences.lastNotifiedKey = alert.dedupKey
    }
}
