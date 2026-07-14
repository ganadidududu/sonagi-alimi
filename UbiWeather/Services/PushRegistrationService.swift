import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import Foundation

/// Bridges this device to the Firebase backend in `firebase/functions`:
/// signs in anonymously (so Firestore rules can scope a doc to `request.auth.uid`),
/// then keeps that device's `devices/{uid}` doc in sync with its FCM token,
/// last-known grid, and notification preferences.
///
/// Everything here is a no-op if Firebase hasn't been configured yet (no
/// `GoogleService-Info.plist` in the bundle) — see `FirebaseBootstrap`.
@MainActor
final class PushRegistrationService: NSObject {
    static let shared = PushRegistrationService()

    /// Callers (`updateGrid`, `updatePreferences`, the FCM token callback) can
    /// fire before sign-in resolves — e.g. `WeatherRepository` gets a location
    /// fix faster than the anonymous-auth round trip. They all await this
    /// same task instead of reading a synchronously-set `uid`, so no update
    /// is silently dropped by the race.
    private var signInTask: Task<String, Error>?

    func start() {
        guard FirebaseBootstrap.isConfigured else { return }
        Messaging.messaging().delegate = self

        signInTask = Task {
            do {
                let result = try await Auth.auth().signInAnonymously()
                return result.user.uid
            } catch {
                NSLog("[Push] anonymous sign-in failed: %@", "\(error)")
                throw error
            }
        }
    }

    func updateGrid(nx: Int, ny: Int) {
        updateDeviceDoc(["nx": nx, "ny": ny])
    }

    func updatePreferences(masterOn: Bool, showerOn: Bool, rainOn: Bool, dndOn: Bool) {
        updateDeviceDoc([
            "notifMasterOn": masterOn,
            "notifShowerOn": showerOn,
            "notifRainOn": rainOn,
            "notifDndOn": dndOn,
        ])
    }

    private func updateFcmToken(_ token: String) {
        updateDeviceDoc(["fcmToken": token])
    }

    private func updateDeviceDoc(_ fields: [String: Any]) {
        guard FirebaseBootstrap.isConfigured else { return }
        Task {
            guard let signInTask, let uid = try? await signInTask.value else { return }
            do {
                try await Firestore.firestore().collection("devices").document(uid)
                    .setData(fields, merge: true)
            } catch {
                NSLog("[Push] Firestore update failed: %@", "\(error)")
            }
        }
    }
}

extension PushRegistrationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in
            self.updateFcmToken(fcmToken)
        }
    }
}
