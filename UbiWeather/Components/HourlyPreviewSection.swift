import SwiftUI

/// The Home screen's "6시간 더보기" horizontal scroll preview.
struct HourlyPreviewSection: View {
    let slots: [HourlySlot]
    var onSeeMore: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("시간별 예보")
                    .font(UbiFont.sectionTitle)
                    .foregroundStyle(Color(hex: 0x3A5170))
                Spacer()
                Button(action: onSeeMore) {
                    Text("6시간 더보기 ›")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x5F7690))
                }
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(slots) { slot in
                        HourlyChip(slot: slot)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
        }
    }
}

private struct HourlyChip: View {
    let slot: HourlySlot

    private var cardFill: Color { slot.isHighlighted ? Color.white.opacity(0.92) : Color.white.opacity(0.62) }
    private var borderColor: Color { slot.isHighlighted ? UbiColors.showerHighlightBorder : Color.white.opacity(0.5) }
    private var hourTextColor: Color { slot.isHighlighted ? UbiColors.showerHighlightLabel : UbiColors.textSub }

    var body: some View {
        VStack(spacing: 0) {
            Text(slot.hourLabel)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(hourTextColor)
            WeatherIconView(condition: slot.condition, size: 34)
                .padding(.vertical, 6)
            Text("\(slot.temperature)°")
                .font(UbiFont.hourlyTemp)
                .foregroundStyle(UbiColors.textBody)
            Text("💧\(slot.precipProbability)%")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(UbiColors.primaryBlue)
                .padding(.top, 4)
        }
        .frame(width: 66)
        .padding(.vertical, 11)
        .background(cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(borderColor, lineWidth: 1))
        .shadow(color: Color(hex: 0x325078, opacity: 0.5), radius: 9, x: 0, y: 4)
    }
}
