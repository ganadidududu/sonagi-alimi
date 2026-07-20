import Foundation
import CoreLocation

/// Remembers whether the user is following GPS or pinned to a chosen region.
///
/// Before this existed, `WeatherRepository.refresh()` always re-read GPS, so any
/// region picked in Settings silently reverted to "내 위치" on the next refresh.
/// The manual choice is stored with its resolved coordinate so refreshes (and
/// cold launches) reuse it without re-geocoding.
enum LocationPreference {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let mode = "loc.mode"            // "current" | "manual"
        static let name = "loc.manualName"
        static let lat = "loc.manualLat"
        static let lon = "loc.manualLon"
    }

    struct ManualRegion {
        let name: String                        // "서울 강남구"
        let coordinate: CLLocationCoordinate2D
    }

    /// `nil` → follow GPS (default).
    static var manualRegion: ManualRegion? {
        guard defaults.string(forKey: Key.mode) == "manual",
              let name = defaults.string(forKey: Key.name),
              defaults.object(forKey: Key.lat) != nil,
              defaults.object(forKey: Key.lon) != nil else { return nil }
        return ManualRegion(
            name: name,
            coordinate: CLLocationCoordinate2D(
                latitude: defaults.double(forKey: Key.lat),
                longitude: defaults.double(forKey: Key.lon)
            )
        )
    }

    static func setManualRegion(name: String, coordinate: CLLocationCoordinate2D) {
        defaults.set("manual", forKey: Key.mode)
        defaults.set(name, forKey: Key.name)
        defaults.set(coordinate.latitude, forKey: Key.lat)
        defaults.set(coordinate.longitude, forKey: Key.lon)
    }

    /// Back to following the device's location.
    static func useCurrentLocation() {
        defaults.set("current", forKey: Key.mode)
        defaults.removeObject(forKey: Key.name)
        defaults.removeObject(forKey: Key.lat)
        defaults.removeObject(forKey: Key.lon)
    }
}
