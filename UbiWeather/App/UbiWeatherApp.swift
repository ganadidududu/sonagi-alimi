import FirebaseMessaging
import SwiftUI
import UIKit

/// `BGTaskScheduler.register(forTaskIdentifier:)` must run before
/// `application(_:didFinishLaunchingWithOptions:)` returns, which SwiftUI's
/// `App.init()`/`.task` don't guarantee — hence this minimal AppDelegate.
/// It also owns APNs registration, since that callback is UIKit-only (no
/// SwiftUI equivalent).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BackgroundRefreshManager.register()
        FirebaseBootstrap.configureIfNeeded()
        if FirebaseBootstrap.isConfigured {
            Task { @MainActor in PushRegistrationService.shared.start() }
            application.registerForRemoteNotifications()
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Push] APNs registration failed: \(error)")
    }
}

@main
struct UbiWeatherApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(UbiColors.deepNavy)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(UbiColors.deepNavy)]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(UbiColors.textMuted2)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(UbiColors.textMuted2)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundRefreshManager.scheduleNextRefresh()
            }
        }
    }
}
