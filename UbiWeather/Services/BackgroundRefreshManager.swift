import BackgroundTasks
import Foundation

/// Best-effort background check for the shower/rain alert via `BGAppRefreshTask`.
///
/// Important honesty note: iOS schedules `BGAppRefreshTask` opportunistically
/// based on the user's app-usage patterns — it is *not* a reliable 10-minute
/// timer. Real "arrives within minutes of the forecast update" reliability
/// needs a server (cron + APNs/FCM). This gets useful best-effort alerts with
/// zero backend, at the cost of that guarantee.
enum BackgroundRefreshManager {
    static let taskIdentifier = "com.ubiweather.app.refresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handle(refreshTask)
        }
    }

    /// Call when the app resigns active — iOS drops any pending request once
    /// the app is foregrounded again, so this must be re-submitted every time.
    static func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        scheduleNextRefresh()  // keep the chain going regardless of this run's outcome

        let work = Task {
            await checkAndNotify()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }

    private static func checkAndNotify() async {
        guard !Secrets.kmaServiceKey.isEmpty, Secrets.kmaServiceKey != "YOUR_KMA_SERVICE_KEY" else { return }
        guard let grid = NotificationPreferences.lastGrid else { return }  // no fix yet — nothing to check

        let client = KMAAPIClient(serviceKey: Secrets.kmaServiceKey)
        guard let items = try? await client.ultraSrtFcst(nx: grid.nx, ny: grid.ny) else { return }
        let slots = KMAParsing.parseHourlySlots(items)
        guard let alert = KMAParsing.evaluateAlert(slots: slots) else { return }
        await NotificationService.postIfNeeded(alert)
    }
}
