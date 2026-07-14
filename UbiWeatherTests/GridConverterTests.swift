import XCTest
@testable import UbiWeather

final class GridConverterTests: XCTestCase {
    /// Seoul City Hall (37.5665, 126.9780) → (60, 127) is the standard
    /// reference pair KMA's own sample code and documentation use to verify
    /// this exact conversion.
    func testSeoulCityHall() {
        let grid = GridConverter.toGrid(latitude: 37.5665, longitude: 126.9780)
        XCTAssertEqual(grid.nx, 60)
        XCTAssertEqual(grid.ny, 127)
    }

    /// Busan (35.1796, 129.0756) → (98, 76) is the other commonly-cited
    /// reference pair.
    func testBusan() {
        let grid = GridConverter.toGrid(latitude: 35.1796, longitude: 129.0756)
        XCTAssertEqual(grid.nx, 98)
        XCTAssertEqual(grid.ny, 76)
    }
}
