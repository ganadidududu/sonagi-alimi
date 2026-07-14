import Foundation
import CoreLocation

/// Converts between WGS84 lat/lon and the KMA Lambert Conformal Conic grid
/// (`nx`, `ny`) that all `VilageFcstInfoService_2.0` endpoints require.
/// Constants and formula are KMA's published standard grid conversion
/// (see `kma_weather_api_spec.md` §6.3).
enum GridConverter {
    struct Grid {
        let nx: Int
        let ny: Int
    }

    private static let re = 6371.00877
    private static let grid = 5.0
    private static let slat1 = 30.0
    private static let slat2 = 60.0
    private static let olon = 126.0
    private static let olat = 38.0
    private static let xo = 43.0
    private static let yo = 136.0
    private static let degrad = Double.pi / 180.0

    static func toGrid(latitude: Double, longitude: Double) -> Grid {
        let re = self.re / grid
        let slat1 = self.slat1 * degrad
        let slat2 = self.slat2 * degrad
        let olon = self.olon * degrad
        let olat = self.olat * degrad

        var sn = tan(Double.pi * 0.25 + slat2 * 0.5) / tan(Double.pi * 0.25 + slat1 * 0.5)
        sn = log(cos(slat1) / cos(slat2)) / log(sn)
        var sf = tan(Double.pi * 0.25 + slat1 * 0.5)
        sf = pow(sf, sn) * cos(slat1) / sn
        var ro = tan(Double.pi * 0.25 + olat * 0.5)
        ro = re * sf / pow(ro, sn)

        var ra = tan(Double.pi * 0.25 + (latitude * degrad) * 0.5)
        ra = re * sf / pow(ra, sn)
        var theta = longitude * degrad - olon
        if theta > Double.pi { theta -= 2 * Double.pi }
        if theta < -Double.pi { theta += 2 * Double.pi }
        theta *= sn

        let x = floor(ra * sin(theta) + xo + 0.5)
        let y = floor(ro - ra * cos(theta) + yo + 0.5)
        return Grid(nx: Int(x), ny: Int(y))
    }

    static func toGrid(coordinate: CLLocationCoordinate2D) -> Grid {
        toGrid(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
