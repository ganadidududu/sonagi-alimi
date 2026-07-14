import SwiftUI

struct DailyView: View {
    @Bindable var vm: WeatherViewModel

    private var minLow: Int { vm.weekly.map(\.low).min() ?? 0 }
    private var maxHigh: Int { vm.weekly.map(\.high).max() ?? 1 }
    private var span: Int { max(maxHigh - minLow, 1) }

    var body: some View {
        ZStack {
            UbiSky.gradient(for: .daily).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("주간 예보")
                        .font(UbiFont.screenTitle)
                        .foregroundStyle(Color(hex: 0x334A68))
                        .padding(.horizontal, 4)
                        .padding(.bottom, 8)

                    ForEach(vm.weekly) { day in
                        row(day)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func row(_ day: DailySummary) -> some View {
        let barLeft = Double(day.low - minLow) / Double(span)
        let barRight = Double(maxHigh - day.high) / Double(span)
        let cardFill = day.isToday ? Color.white.opacity(0.9) : Color.white.opacity(0.6)
        let border = day.isToday ? UbiColors.showerHighlightBorder : Color.white.opacity(0.5)
        let dayColor = day.isToday ? UbiColors.showerHighlightLabel : UbiColors.textBody

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(day.dayLabel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(dayColor)
                if let date = day.dateLabel {
                    Text(date)
                        .font(.system(size: 11))
                        .foregroundStyle(UbiColors.textMuted2)
                }
            }
            .frame(width: 52, alignment: .leading)

            WeatherIconView(condition: day.condition, size: 30)

            Text("💧\(day.precipProbability)%")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(UbiColors.primaryBlue)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 9) {
                Text("\(day.low)°")
                    .font(UbiFont.dailyTemp)
                    .foregroundStyle(Color(hex: 0x98A8BD))
                    .frame(width: 26, alignment: .trailing)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: 0xE3EBF3))
                        Capsule()
                            .fill(UbiTempRangeGradient.gradient)
                            .frame(width: geo.size.width * (1 - barLeft - barRight))
                            .offset(x: geo.size.width * barLeft)
                    }
                }
                .frame(width: 64, height: 6)

                Text("\(day.high)°")
                    .font(UbiFont.dailyTemp)
                    .foregroundStyle(UbiColors.textBody)
                    .frame(width: 26, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(border, lineWidth: 1))
    }
}

#Preview {
    DailyView(vm: WeatherViewModel())
}
