import SwiftUI

struct HourlyView: View {
    @Bindable var vm: WeatherViewModel

    var body: some View {
        ZStack {
            UbiSky.gradient(for: .hourly).ignoresSafeArea()
            if vm.rainAnimationEnabled { RainOverlayView() }

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("6시간 타임라인")
                        .font(UbiFont.screenTitle)
                        .foregroundStyle(Color(hex: 0x334A68))
                        .padding(.horizontal, 4)

                    Text("\(vm.locationName) · 초단기예보")
                        .font(.system(size: 12.5))
                        .foregroundStyle(UbiColors.textSub)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 12)

                    peakBanner

                    VStack(spacing: 9) {
                        ForEach(vm.hourly) { slot in
                            row(slot)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var peakBanner: some View {
        HStack(spacing: 10) {
            Text("🌦").font(.system(size: 22))
            Text(vm.peakPrecipWindowText)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(vm.accent.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: vm.accent.shadowColor, radius: 13, x: 0, y: 12)
        .padding(.bottom, 16)
    }

    private func row(_ slot: HourlySlot) -> some View {
        let cardFill = slot.isHighlighted ? Color.white.opacity(0.92) : Color.white.opacity(0.62)
        let border = slot.isHighlighted ? UbiColors.showerHighlightBorder : Color.white.opacity(0.5)
        let hourColor = slot.isHighlighted ? UbiColors.showerHighlightLabel : UbiColors.textSub

        return HStack(spacing: 14) {
            Text(slot.hourLabel)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(hourColor)
                .frame(width: 44, alignment: .leading)

            WeatherIconView(condition: slot.condition, size: 34)

            Text(slot.conditionLabel)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(UbiColors.textSub)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 5) {
                Text("💧\(slot.precipProbability)%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(UbiColors.primaryBlue)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: 0xE3EBF3))
                        Capsule().fill(UbiColors.primaryBlue)
                            .frame(width: geo.size.width * CGFloat(slot.precipProbability) / 100)
                    }
                }
                .frame(width: 52, height: 5)
            }
            .frame(width: 56)

            Text("\(slot.temperature)°")
                .font(UbiFont.hourlyTemp)
                .foregroundStyle(UbiColors.textBody)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(border, lineWidth: 1))
    }
}

#Preview {
    HourlyView(vm: WeatherViewModel())
}
