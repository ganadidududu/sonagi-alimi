import CoreLocation
import Observation

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    /// Resumed by the delegate once the user answers the permission prompt.
    private var authContinuation: CheckedContinuation<Void, Never>?

    private(set) var authorizationStatus: CLAuthorizationStatus

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }

    /// Shows the system prompt (if still undecided) and waits for the answer.
    /// Returns immediately once the status is already decided.
    @discardableResult
    func requestPermissionAndWait() async -> CLAuthorizationStatus {
        guard manager.authorizationStatus == .notDetermined else {
            return manager.authorizationStatus
        }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            authContinuation = cont
            manager.requestWhenInUseAuthorization()
        }
        return manager.authorizationStatus
    }

    /// Single-shot location fetch — a weather app has no need for continuous updates.
    ///
    /// The permission prompt is asynchronous, so we must wait for the user's
    /// answer before asking for a fix. Firing `requestLocation()` while the
    /// status is still `.notDetermined` fails immediately, which used to strand
    /// first-launch users on the "권한이 필요해요" screen until they relaunched.
    func requestLocation() async throws -> CLLocationCoordinate2D {
        if manager.authorizationStatus == .notDetermined {
            await requestPermissionAndWait()
        }
        guard !isDenied else { throw CLError(.denied) }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        // Only the user's actual decision ends the wait — the delegate also
        // fires once with `.notDetermined` right after the delegate is set.
        if manager.authorizationStatus != .notDetermined {
            authContinuation?.resume()
            authContinuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        continuation?.resume(returning: coordinate)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
