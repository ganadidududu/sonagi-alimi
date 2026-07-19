import SwiftUI
import WidgetKit

/// `systemMedium` home-screen widget — full color (unlike the lock-screen one).
/// Top strip = alert banner (shower/rain) or current-conditions header; below
/// it, the next 6 hourly slots. Matches `homescreen-widget-reference.html`.
struct HomeWidgetView: View {
    let entry: HomeWidgetEntry
    @Environment(\.colorScheme) private var scheme
    private var dark: Bool { scheme == .dark }

    var body: some View {
        content
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder
    private var content: some View {
        switch entry.content {
        case .placeholder:
            skeleton
        case .noLocation:
            emptyState
        case .snapshot(let snap):
            VStack(spacing: 10) {
                topStrip(snap)
                columns(snap.slots)
            }
        }
    }

    // MARK: Top strip

    @ViewBuilder
    private func topStrip(_ snap: HomeWidgetSnapshot) -> some View {
        if let alert = snap.alert {
            banner(alert)
        } else {
            header(snap)
        }
    }

    private func banner(_ alert: HomeWidgetSnapshot.Alert) -> some View {
        let isShower = alert.kind == .shower
        let grad = isShower
            ? [Color(hex: 0xF9A94A), Color(hex: 0xF4832F)]
            : [Color(hex: 0x5AA6EA), Color(hex: 0x3F7FD0)]
        let cond: WeatherCondition = isShower ? .shower : .rain
        let title = isShower ? "소나기 임박" : "비 예정"
        let sub = alert.minutesUntil > 60
            ? alert.startText
            : "\(alert.startText) · \(alert.minutesUntil)분 후"
        return HStack(spacing: 8) {
            WeatherIconView(condition: cond, size: 22, forceFace: true)
            Text(title).font(.system(size: 13, weight: .semibold))
            Text("·").font(.system(size: 12)).opacity(0.7)
            Text(sub).font(.system(size: 11.5)).opacity(0.9)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(LinearGradient(colors: grad, startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: grad[1].opacity(0.35), radius: 6, y: 3)
    }

    private func header(_ snap: HomeWidgetSnapshot) -> some View {
        let cond = WeatherCondition(rawValue: snap.currentCondition) ?? .cloudy
        return HStack(spacing: 6) {
            Text("📍").font(.system(size: 12))
            Text(snap.locationName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(dark ? Color(hex: 0xEAF2FB) : UbiColors.textBody)
                .lineLimit(1)
            Spacer(minLength: 8)
            WeatherIconView(condition: cond, size: 20, forceFace: true)
            Text("지금 \(snap.currentTemp)° · \(cond.label)")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(dark ? Color(hex: 0xC3D3E2) : UbiColors.textSub)
                .lineLimit(1)
        }
        .frame(height: 30)
    }

    // MARK: 6-hour columns

    private func columns(_ slots: [HomeWidgetSnapshot.Slot]) -> some View {
        let maxIdx = highestPrecipIndex(slots)
        return HStack(spacing: 0) {
            ForEach(Array(slots.enumerated()), id: \.offset) { idx, slot in
                column(slot, highlighted: idx == maxIdx)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func column(_ slot: HomeWidgetSnapshot.Slot, highlighted: Bool) -> some View {
        let cond = WeatherCondition(rawValue: slot.condition) ?? .cloudy
        let hourColor = highlighted
            ? (dark ? Color(hex: 0xFFCF6B) : Color(hex: 0xE6892A))
            : (dark ? Color(hex: 0xA9BCD6) : UbiColors.textMuted)
        return VStack(spacing: 4) {
            Text(slot.hourLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(hourColor)
                .lineLimit(1)
            WeatherIconView(condition: cond, size: 34, forceFace: true)
            Text("\(slot.temperature)°")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(dark ? Color(hex: 0xEEF3F8) : UbiColors.textBody)
            Text("💧\(slot.precipProbability)%")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(dark ? Color(hex: 0x8FC0F5) : UbiColors.primaryBlue)
        }
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(highlighted ? (dark ? Color.white.opacity(0.14) : Color.white.opacity(0.62)) : .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(highlighted ? (dark ? Color(hex: 0xFFC978).opacity(0.5) : Color(hex: 0xF7C68A)) : .clear, lineWidth: 1)
                )
        )
    }

    private func highestPrecipIndex(_ slots: [HomeWidgetSnapshot.Slot]) -> Int? {
        guard let m = slots.enumerated().max(by: { $0.element.precipProbability < $1.element.precipProbability }),
              m.element.precipProbability >= 50 else { return nil }
        return m.offset
    }

    // MARK: States

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("☂️").font(.system(size: 30))
            Text("앱에서 위치를 설정해 주세요")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(dark ? Color(hex: 0xEAF2FB) : Color(hex: 0x33475F))
            Text("탭하여 열기")
                .font(.system(size: 11))
                .foregroundStyle(dark ? Color(hex: 0x9FB4CF) : Color(hex: 0x67788F))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "ubiweather://settings"))
    }

    private var skeleton: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 12).frame(height: 30)
            HStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { _ in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4).frame(width: 24, height: 10)
                        Circle().frame(width: 30, height: 30)
                        RoundedRectangle(cornerRadius: 4).frame(width: 22, height: 12)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .foregroundStyle(.gray.opacity(0.3))
        .redacted(reason: .placeholder)
    }

    private var background: some View {
        LinearGradient(
            colors: dark
                ? [Color(hex: 0x2F4A6D), Color(hex: 0x26374D)]
                : [Color(hex: 0x8BA6C8), Color(hex: 0xAEC3DC), Color(hex: 0xDBE6F0)],
            startPoint: .top, endPoint: .bottom
        )
    }
}
