import SwiftUI

struct DailyView: View {
    @Bindable var vm: WeatherViewModel
    /// The day whose consensus detail sheet is open, if any.
    @State private var sheetDay: DailySummary?

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

                    if let summary = vm.consensusSummary {
                        consensusPill(summary)
                    }

                    Color.clear.frame(height: 0).padding(.bottom, 4)

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
        .sheet(item: $sheetDay) { day in
            if let consensus = day.consensus {
                ConsensusSheet(day: day, consensus: consensus)
            }
        }
    }

    /// Header pill: "⚖️ 기상청·ECMWF·ICON 합의" or a fallback warning.
    private func consensusPill(_ summary: WeatherViewModel.ConsensusSummary) -> some View {
        let warn = summary == .fallback
        return HStack(spacing: 6) {
            Text(summary.pillIcon).font(.system(size: 12))
            Text(summary.pillText)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(warn ? Color(hex: 0xC47B1A) : UbiColors.textSub)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(warn ? Color(hex: 0xFFF8EC) : Color.white.opacity(0.6))
        .overlay(
            Capsule().stroke(warn ? Color(hex: 0xF4DCAE) : Color.white.opacity(0.7), lineWidth: 1)
        )
        .clipShape(Capsule())
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private func row(_ day: DailySummary) -> some View {
        let barLeft = Double(day.low - minLow) / Double(span)
        let barRight = Double(maxHigh - day.high) / Double(span)
        let badge = day.consensus?.badgeText
        // A split verdict earns the same warm amber treatment as "today",
        // matching the reference (#fffaf3 fill, amber border).
        let warm = badge != nil
        let cardFill = warm ? Color(hex: 0xFFFAF3)
            : day.isToday ? Color.white.opacity(0.9) : Color.white.opacity(0.6)
        let border = (warm || day.isToday) ? UbiColors.showerHighlightBorder : Color.white.opacity(0.5)
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

            HStack(spacing: 5) {
                Text("💧\(day.precipProbability)%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(UbiColors.primaryBlue)
                    .fixedSize()
                if let badge {
                    consensusBadge(badge)
                }
            }
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
        // Only consensus-bearing days are tappable; a KMA-only day has no detail
        // to show, so it stays inert.
        .contentShape(Rectangle())
        .onTapGesture { if day.consensus != nil { sheetDay = day } }
    }

    private func consensusBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold))
            .foregroundStyle(UbiColors.showerHighlightLabel)
            .fixedSize()
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(Color(hex: 0xFFF3E0))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(UbiColors.showerHighlightBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

#Preview {
    DailyView(vm: WeatherViewModel())
}
