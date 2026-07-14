import SwiftUI
import WidgetKit
import UIKit

/// `.accessoryRectangular` only (spec §2). Layout/typography/color rules are
/// spec §4-6; the icon uses the app's cute "face" `WeatherIconView` in its
/// natural colors via `.widgetAccentedRenderingMode(.fullColor)` (iOS 18+)
/// rather than a flattened SF Symbol — matching the reference mockup, which
/// keeps the face icon's yellow/white/blue regardless of the chosen lock
/// screen tint. That modifier only exists on `Image`, not an arbitrary View,
/// so the Canvas-drawn `WeatherIconView` is rasterized once via
/// `ImageRenderer` and wrapped as an `Image` before applying it. On iOS 17
/// (no fullColor override) it falls back to the system's default accented
/// treatment for that subtree.
struct LockScreenWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        Group {
            switch entry.content {
            case .placeholder:
                placeholderRow
            case .noLocation:
                row(
                    icon: AnyView(
                        Image(systemName: "location.slash")
                            .font(.system(size: 22, weight: .semibold))
                            .widgetAccentable()
                    ),
                    line1: "위치를 설정해 주세요",
                    line2: "탭하여 열기",
                    accessibilityLabel: "위치가 설정되지 않았습니다. 앱을 열어 위치를 설정해 주세요"
                )
                .widgetURL(URL(string: "ubiweather://settings"))
            case .snapshot(let snapshot):
                row(
                    icon: AnyView(weatherIcon(for: snapshot)),
                    line1: snapshot.line1,
                    line2: snapshot.line2,
                    accessibilityLabel: snapshot.accessibilityLabel
                )
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    @ViewBuilder
    private func weatherIcon(for snapshot: WidgetWeatherSnapshot) -> some View {
        if let condition = WeatherCondition(rawValue: snapshot.weatherCondition),
           let rendered = Self.renderedIcon(for: condition) {
            fullColorImage(Image(uiImage: rendered))
        } else {
            Image(systemName: "questionmark.circle").widgetAccentable()
        }
    }

    @ViewBuilder
    private func fullColorImage(_ image: Image) -> some View {
        // `.widgetAccentedRenderingMode` only exists on `Image`, so it must be
        // applied before `.aspectRatio` erases the type to `some View`.
        if #available(iOS 18.0, *) {
            image.resizable().widgetAccentedRenderingMode(.fullColor).aspectRatio(contentMode: .fit)
        } else {
            image.resizable().aspectRatio(contentMode: .fit)
        }
    }

    /// One-shot rasterization of the app's Canvas-based icon into a bitmap —
    /// cheap enough per timeline render (5 possible conditions, 26pt square).
    private static func renderedIcon(for condition: WeatherCondition) -> UIImage? {
        let renderer = ImageRenderer(content: WeatherIconView(condition: condition, size: 64))
        renderer.scale = 3
        return renderer.uiImage
    }

    private func row(icon: AnyView, line1: String, line2: String, accessibilityLabel: String) -> some View {
        HStack(spacing: 8) {
            icon.frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(line1)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .widgetAccentable()
                    .lineLimit(1)
                Text(line2)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var placeholderRow: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6).frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4).frame(height: 12)
                RoundedRectangle(cornerRadius: 4).frame(width: 60, height: 10)
            }
        }
        .redacted(reason: .placeholder)
    }
}

#Preview("A · 소나기", as: .accessoryRectangular) {
    UbiWeatherLockScreenWidget()
} timeline: {
    WidgetEntry(date: .now, content: .snapshot(WidgetWeatherSnapshot(
        kind: .shower, line1: "소나기 임박", line2: "오후 3시~4시 · 13분 후",
        accessibilityLabel: "13분 후 오후 3시부터 4시까지 소나기가 예상됩니다",
        weatherCondition: WeatherCondition.shower.rawValue, updatedAt: .now
    )))
}

#Preview("C · 안심", as: .accessoryRectangular) {
    UbiWeatherLockScreenWidget()
} timeline: {
    WidgetEntry(date: .now, content: .snapshot(WidgetWeatherSnapshot(
        kind: .calm, line1: "비 걱정 없어요", line2: "22° · 흐림",
        accessibilityLabel: "오늘 강수확률이 낮아 비 걱정이 없습니다. 현재 기온 22도, 흐림",
        weatherCondition: WeatherCondition.cloudy.rawValue, updatedAt: .now
    )))
}

#Preview("E · 위치 없음", as: .accessoryRectangular) {
    UbiWeatherLockScreenWidget()
} timeline: {
    WidgetEntry(date: .now, content: .noLocation)
}
