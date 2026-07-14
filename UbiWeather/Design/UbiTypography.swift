import SwiftUI

/// "Jua" is the brand's rounded display font (numbers, temperatures, titles).
/// Falls back to the system rounded font if the bundled font file is missing.
enum UbiFont {
    private static let familyName = "Jua-Regular"
    private static var isAvailable: Bool = {
        UIFont.familyNames.contains { $0.contains("Jua") }
            || UIFont(name: familyName, size: 12) != nil
    }()

    static func jua(_ size: CGFloat) -> Font {
        if isAvailable {
            return .custom(familyName, size: size)
        }
        return .system(size: size, weight: .regular, design: .rounded)
    }

    // Fixed sizes used across the Home screen, taken 1:1 from the design spec.
    static let bigTemperature = jua(62)
    static let bannerTitle = jua(27)
    static let bannerMinutes = jua(16)
    static let screenTitle = jua(22)
    static let sectionTitle = jua(16)
    static let currentDegreeUnit = jua(24)
    static let chipValue = jua(19)
    static let hourlyTemp = jua(17)
    static let dailyTemp = jua(14)
    static let locationHeader = jua(17)
    static let pillLabel = jua(15)
    static let buttonLabel = jua(16)
}
