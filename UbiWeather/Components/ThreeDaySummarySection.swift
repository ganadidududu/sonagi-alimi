import SwiftUI

struct ThreeDaySummarySection: View {
    let days: [DailySummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("오늘 · 내일 · 모레")
                .font(UbiFont.sectionTitle)
                .foregroundStyle(Color(hex: 0x3A5170))
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(days) { day in
                    row(day)
                }
            }
        }
    }

    private func row(_ day: DailySummary) -> some View {
        HStack(spacing: 12) {
            Text(day.dayLabel)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(Color(hex: 0x465D78))
                .frame(width: 42, alignment: .leading)

            WeatherIconView(condition: day.condition, size: 32)

            Text(day.conditionLabel)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(UbiColors.textSub)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("💧\(day.precipProbability)%")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(UbiColors.primaryBlue)
                .frame(width: 44, alignment: .trailing)

            Text("\(day.low)°")
                .font(UbiFont.dailyTemp)
                .foregroundStyle(Color(hex: 0x98A8BD))
                .frame(width: 30, alignment: .trailing)

            Text("\(day.high)°")
                .font(UbiFont.dailyTemp)
                .foregroundStyle(UbiColors.textBody)
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.66))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
