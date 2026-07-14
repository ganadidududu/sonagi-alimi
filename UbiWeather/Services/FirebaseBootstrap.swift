import FirebaseCore
import Foundation

/// `FirebaseApp.configure()` calls `fatalError` if `GoogleService-Info.plist`
/// is missing from the bundle. Since that file can't be checked into git (it's
/// tied to a specific Firebase project the user creates themselves), guard
/// every Firebase call behind this so the app keeps working in "local-only"
/// mode until the user drops their real plist in.
enum FirebaseBootstrap {
    static let isConfigured: Bool = {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }()

    static func configureIfNeeded() {
        guard isConfigured else {
            print("[Firebase] GoogleService-Info.plist not found — running in local-notifications-only mode.")
            return
        }
        FirebaseApp.configure()
    }
}
