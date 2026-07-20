import SwiftUI

/// The killer feature: a big top-of-home card announcing rain/shower within
/// the next 2 hours. Color + icon + text convey the state (not color alone),
/// per the handoff's colorblind-accessibility requirement.
struct AlertBannerView: View {
    let level: AlertLevel
    let icon: WeatherCondition
    let accent: AlertAccent
    var animated: Bool = true

    @State private var shineOffset: CGFloat = -1.2
    @State private var pulse = false

    var body: some View {
        if case .none = level {
            EmptyView()
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let badge = level.badgeText {
                Text(badge)
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.28)))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(pulse ? 0 : 0.5), lineWidth: pulse ? 12 : 0)
                            .opacity(pulse ? 0 : 0.7)
                    )
                    .scaleEffect(pulse ? 1.05 : 1)
            }

            HStack(alignment: .center, spacing: 14) {
                WeatherIconView(condition: icon, size: 76, bob: animated)

                VStack(alignment: .leading, spacing: 8) {
                    Text(titleText)
                        .font(UbiFont.bannerTitle)
                        .lineSpacing(2)
                    subtitleText
                        .font(.system(size: 13.5, weight: .medium))
                        .opacity(0.95)
                }
            }
            .padding(.top, 14)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(shine.clipShape(RoundedRectangle(cornerRadius: 28)))
        .shadow(color: accent.shadowColor, radius: 18, x: 0, y: 10)
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { pulse = true }
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: false)) { shineOffset = 2.2 }
        }
    }

    private var shine: some View {
        GeometryReader { geo in
            LinearGradient(colors: [Color.white.opacity(0.32), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: geo.size.width * 0.6)
                .rotationEffect(.degrees(20))
                .offset(x: shineOffset * geo.size.width)
        }
        .allowsHitTesting(false)
    }

    private var titleText: String {
        switch level {
        case .shower(let window, _): return "\(window)\n소나기가 지나가요"
        case .rain(let window, _): return "\(window)\n비가 내려요"
        case .none: return ""
        }
    }

    @ViewBuilder
    private var subtitleText: some View {
        switch level {
        case .shower(_, let timing):
            timingLine(timing, tail: " · 우산을 꼭 챙기세요 ☂️")
        case .rain(_, let timing):
            timingLine(timing, tail: " · 우산을 챙기세요 ☂️")
        case .none:
            Text("")
        }
    }

    /// Already raining → no countdown; it used to claim "N분 뒤 시작" mid-downpour.
    private func timingLine(_ timing: AlertTiming, tail: String) -> Text {
        switch timing {
        case .ongoing:
            return Text("지금 내리는 중").font(UbiFont.bannerMinutes) + Text(tail)
        case .startsIn:
            return Text("약 ") + Text(timing.shortText).font(UbiFont.bannerMinutes) + Text(" 뒤 시작" + tail)
        }
    }
}

#Preview {
    AlertBannerView(
        level: .shower(windowText: "오후 3시~오후 5시", timing: .startsIn(minutes: 13)),
        icon: .shower,
        accent: .amber
    )
    .padding()
    .background(UbiSky.gradient(for: .home))
}
