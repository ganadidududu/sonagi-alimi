import SwiftUI

enum UbiTab: String, CaseIterable, Identifiable {
    case home, hourly, daily, radar, settings
    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: return "홈"
        case .hourly: return "시간별"
        case .daily: return "일별"
        case .radar: return "레이더"
        case .settings: return "설정"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .hourly: return "clock.fill"
        case .daily: return "calendar"
        case .radar: return "dot.radiowaves.left.and.right"
        case .settings: return "gearshape.fill"
        }
    }
}

enum AlertAccent: String, CaseIterable {
    case amber = "앰버(따뜻)"
    case coral = "코랄"
    case violet = "바이올렛"

    var gradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .amber: colors = [Color(hex: 0xF9A94A), Color(hex: 0xF4832F)]
        case .coral: colors = [Color(hex: 0xFF8A6B), Color(hex: 0xF2624A)]
        case .violet: colors = [Color(hex: 0x8B7CF0), Color(hex: 0x6A54D8)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var shadowColor: Color {
        switch self {
        case .amber: return Color(hex: 0xF4832F, opacity: 0.55)
        case .coral: return Color(hex: 0xF2624A, opacity: 0.55)
        case .violet: return Color(hex: 0x6A54D8, opacity: 0.55)
        }
    }
}

enum UbiSky {
    /// Vertical (top->bottom) sky gradients, one per tab. `nil` tab key covers loading/error/locationDenied.
    static func gradient(for tab: UbiTab?) -> LinearGradient {
        let stops: [Gradient.Stop]
        switch tab {
        case .home, .hourly:
            stops = [
                .init(color: Color(hex: 0x8BA6C8), location: 0),
                .init(color: Color(hex: 0xAEC3DC), location: 0.42),
                .init(color: Color(hex: 0xDBE6F0), location: 1),
            ]
        case .daily:
            stops = [
                .init(color: Color(hex: 0x8ECBF2), location: 0),
                .init(color: Color(hex: 0xBFE2F8), location: 0.45),
                .init(color: Color(hex: 0xEAF6FF), location: 1),
            ]
        case .radar:
            stops = [
                .init(color: Color(hex: 0x6A7F9C), location: 0),
                .init(color: Color(hex: 0x8BA0BB), location: 0.55),
                .init(color: Color(hex: 0xC3D3E2), location: 1),
            ]
        case .settings:
            stops = [
                .init(color: Color(hex: 0xC9D6E4), location: 0),
                .init(color: Color(hex: 0xDDE7F0), location: 0.5),
                .init(color: Color(hex: 0xEEF3F8), location: 1),
            ]
        case nil:
            stops = [
                .init(color: Color(hex: 0xDBE6F0), location: 0),
                .init(color: Color(hex: 0xEEF3F8), location: 1),
            ]
        }
        return LinearGradient(gradient: Gradient(stops: stops), startPoint: .top, endPoint: .bottom)
    }
}

/// Low-min-to-high-max temperature range bar gradient used in the Daily list.
enum UbiTempRangeGradient {
    static let gradient = LinearGradient(
        colors: [Color(hex: 0x7FC8F0), Color(hex: 0xF4A13C)],
        startPoint: .leading, endPoint: .trailing
    )
}
