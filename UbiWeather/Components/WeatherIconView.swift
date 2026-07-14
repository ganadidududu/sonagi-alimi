import SwiftUI

/// Custom "cute rounded weather icon" — ported 1:1 (same coordinates, same
/// 64x64 viewBox) from the `ic(type, size)` icon generator in the design
/// reference HTML. Large icons (>=60pt) get a face (eyes/smile/blush);
/// small ones (timeline/daily rows) stay plain, matching the reference.
struct WeatherIconView: View {
    let condition: WeatherCondition
    var size: CGFloat = 64
    var bob: Bool = false

    @State private var bobUp = false

    var body: some View {
        Canvas { context, canvasSize in
            let scale = canvasSize.width / 64
            context.scaleBy(x: scale, y: scale)
            let hasFace = size >= 60

            switch condition {
            case .sunny:
                drawSun(&context, big: true)
            case .partly:
                drawSunSmall(&context, at: CGPoint(x: 46, y: 20))
                drawCloud(&context, fill: Color.white, shadow: Color(hex: 0x8AA0BC), withFace: hasFace)
            case .cloudy:
                drawCloud(&context, fill: Color(hex: 0xCDD8E6), shadow: Color(hex: 0x7D90AB), withFace: hasFace)
            case .rain:
                drawCloud(&context, fill: Color(hex: 0xC2CFE0), shadow: Color(hex: 0x7D90AB), withFace: hasFace)
                drawDrops(&context, color: UbiColors.primaryBlue, points: [
                    (24, 52, 3), (33, 55, 3.4), (42, 52, 3),
                ])
            case .shower:
                drawSunSmall(&context, at: CGPoint(x: 15, y: 16))
                drawCloud(&context, fill: Color(hex: 0xA9BCD6), shadow: Color(hex: 0x5B7690), withFace: hasFace)
                drawDrops(&context, color: UbiColors.primaryBlue, points: [
                    (24, 52, 3.2), (33, 55, 3.6), (42, 52, 3.2), (33, 60, 3),
                ])
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Color(hex: 0x32_5078, opacity: 0.14), radius: 3, x: 0, y: 4)
        .offset(y: bob && bobUp ? -6 : 0)
        .animation(bob ? .easeInOut(duration: 3).repeatForever(autoreverses: true) : nil, value: bobUp)
        .onAppear { if bob { bobUp = true } }
    }

    // MARK: - Drawing primitives (coordinates match the 0...64 viewBox 1:1)

    private func drawSun(_ context: inout GraphicsContext, big: Bool) {
        for i in 0..<8 {
            let angle = Angle.degrees(Double(i) * 45)
            var ray = Path()
            ray.move(to: CGPoint(x: 32, y: 5))
            ray.addLine(to: CGPoint(x: 32, y: 12))
            let rotated = ray.applying(
                CGAffineTransform(translationX: 32, y: 32)
                    .rotated(by: angle.radians)
                    .translatedBy(x: -32, y: -32)
            )
            context.stroke(rotated, with: .color(Color(hex: 0xFFC24A)), style: StrokeStyle(lineWidth: 4.4, lineCap: .round))
        }
        let sunRect = CGRect(x: 18, y: 18, width: 28, height: 28)
        context.fill(
            Path(ellipseIn: sunRect),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFE27A), Color(hex: 0xFFB43B)]),
                center: CGPoint(x: 28.6, y: 27.5),
                startRadius: 0,
                endRadius: 14
            )
        )
        if big { drawFace(&context, cx: 32, cy: 32, scale: 1, color: Color(hex: 0x7A5A12)) }
    }

    private func drawSunSmall(_ context: inout GraphicsContext, at point: CGPoint) {
        let rect = CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFE27A), Color(hex: 0xFFB43B)]),
                center: CGPoint(x: point.x - 1.4, y: point.y - 1.5),
                startRadius: 0,
                endRadius: 9
            )
        )
    }

    private func drawCloud(_ context: inout GraphicsContext, fill: Color, shadow: Color, withFace: Bool) {
        // soft ground shadow
        context.fill(Path(ellipseIn: CGRect(x: 32 - 21, y: 40 - 12, width: 42, height: 24)),
                      with: .color(Color(hex: 0x3C_5A82, opacity: 0.10)))
        var body = Path()
        body.addEllipse(in: CGRect(x: 23 - 12, y: 34 - 12, width: 24, height: 24))
        body.addEllipse(in: CGRect(x: 43 - 13, y: 32 - 13, width: 26, height: 26))
        body.addEllipse(in: CGRect(x: 33 - 12.5, y: 25 - 12.5, width: 25, height: 25))
        body.addRoundedRect(in: CGRect(x: 12, y: 32, width: 40, height: 15), cornerSize: CGSize(width: 7.5, height: 7.5))
        context.fill(body, with: .color(fill))

        if withFace {
            drawFace(&context, cx: 33, cy: 36.5, scale: 1, color: shadow, spread: 6, dy: 2.5)
            context.fill(Path(ellipseIn: CGRect(x: 22 - 2.4, y: 37 - 2.4, width: 4.8, height: 4.8)),
                          with: .color(Color(hex: 0xFF9696, opacity: 0.35)))
            context.fill(Path(ellipseIn: CGRect(x: 44 - 2.4, y: 36 - 2.4, width: 4.8, height: 4.8)),
                          with: .color(Color(hex: 0xFF9696, opacity: 0.35)))
        }
    }

    /// Two dot eyes + a smile arc, shared by the sun and cloud "faces".
    private func drawFace(_ context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, scale: CGFloat, color: Color, spread: CGFloat = 4, dy: CGFloat = 3) {
        context.fill(Path(ellipseIn: CGRect(x: cx - spread - 1.7 * scale, y: cy - 1.7 * scale, width: 3.4 * scale, height: 3.4 * scale)), with: .color(color))
        context.fill(Path(ellipseIn: CGRect(x: cx + spread - 1.7 * scale, y: cy - 1.7 * scale, width: 3.4 * scale, height: 3.4 * scale)), with: .color(color))
        var smile = Path()
        smile.move(to: CGPoint(x: cx - spread * 0.85, y: cy + dy))
        smile.addQuadCurve(to: CGPoint(x: cx + spread * 0.85, y: cy + dy), control: CGPoint(x: cx, y: cy + dy + spread * 0.75))
        context.stroke(smile, with: .color(color), style: StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round))
    }

    private func drawDrops(_ context: inout GraphicsContext, color: Color, points: [(CGFloat, CGFloat, CGFloat)]) {
        for p in points {
            context.fill(Path(ellipseIn: CGRect(x: p.0 - p.2, y: p.1 - p.2, width: p.2 * 2, height: p.2 * 2)), with: .color(color))
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach([WeatherCondition.sunny, .partly, .cloudy, .rain, .shower], id: \.self) { c in
            WeatherIconView(condition: c, size: 66, bob: true)
        }
    }
    .padding(40)
    .background(UbiSky.gradient(for: .home))
}
