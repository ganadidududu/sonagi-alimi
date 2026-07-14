import SwiftUI

/// Ambient falling raindrops shown behind Home/Hourly content. Purely
/// decorative — ported from the reference's `ubi-rainfall` keyframes.
/// Respects Reduce Motion by not animating (per the handoff's accessibility note).
struct RainOverlayView: View {
    private let dropCount = 26
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fallen = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                ForEach(0..<dropCount, id: \.self) { i in
                    Capsule()
                        .fill(UbiColors.raindrop)
                        .frame(width: 2, height: 13)
                        .position(
                            x: geo.size.width * (CGFloat((i * 39) % 1000) / 1000.0),
                            y: fallen ? geo.size.height + 20 : -20
                        )
                        .opacity(fallen ? 0.1 : 0.7)
                        .animation(
                            reduceMotion ? nil :
                                .linear(duration: 0.75 + Double(i % 5) * 0.12)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i % 7) * 0.13),
                            value: fallen
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { if !reduceMotion { fallen = true } }
    }
}
