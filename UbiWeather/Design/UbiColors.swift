import SwiftUI

/// Design tokens extracted from `design_handoff_ubi_weather/ubi-weather-reference.html`.
enum UbiColors {
    // Brand / text
    static let primaryBlue = Color(hex: 0x4A90E2)
    static let deepNavy = Color(hex: 0x2F4A6D)
    static let toggleOn = Color(hex: 0x3AA76D)
    static let warnDot = Color(hex: 0xF4A13C)

    // Text hierarchy
    static let textStrong = Color(hex: 0x2F4762)
    static let textBody = Color(hex: 0x3F5670)
    static let textSub = Color(hex: 0x5B7690)
    static let textMuted = Color(hex: 0x8598AE)
    static let textMuted2 = Color(hex: 0x9AABC0)
    static let textDesc = Color(hex: 0x67788F)

    // Surfaces
    static let offlineStrip = Color(hex: 0x5B6B80)
    static let showerHighlightBorder = Color(hex: 0xF7C68A)
    static let showerHighlightLabel = Color(hex: 0xE6892A)
    static let skeletonLight = Color(hex: 0xE6ECF3)
    static let skeletonDark = Color(hex: 0xF3F7FB)
    static let raindrop = Color.white.opacity(0.55)
    static let cardFill = Color.white.opacity(0.72)
    static let cardFillLight = Color.white.opacity(0.62)
    static let toggleOffTrack = Color(hex: 0xC8D3E0)
    static let divider = Color(hex: 0xEAF0F6)

    static let navActive = deepNavy
    static let navInactive = textMuted2
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
