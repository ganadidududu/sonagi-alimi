import SwiftUI

struct CurrentWeatherCardView: View {
    let temperature: Int
    let summaryLabel: String
    let icon: WeatherCondition
    let humidityPercent: Int
    let windSpeed: String
    let precipProbability: Int
    var animated: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .top, spacing: 2) {
                        Text("\(temperature)")
                            .font(UbiFont.bigTemperature)
                        Text("°")
                            .font(UbiFont.currentDegreeUnit)
                            .padding(.top, 6)
                    }
                    .foregroundStyle(UbiColors.textStrong)

                    Text(summaryLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x5A6D85))
                }
                Spacer()
                WeatherIconView(condition: icon, size: 66, bob: animated)
            }

            HStack(spacing: 9) {
                chip(label: "습도", value: "\(humidityPercent)%")
                chip(label: "바람", value: windSpeed)
                chip(label: "강수확률", value: "\(precipProbability)%")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial)
        .background(UbiColors.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: Color(hex: 0x325078, opacity: 0.5), radius: 13, x: 0, y: 5)
    }

    private func chip(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(UbiColors.textMuted)
            Text(value)
                .font(UbiFont.chipValue)
                .foregroundStyle(UbiColors.textBody)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    CurrentWeatherCardView(temperature: 22, summaryLabel: "흐림 · 곧 비 · 체감 21°", icon: .cloudy, humidityPercent: 78, windSpeed: "2.4㎧", precipProbability: 80)
        .padding()
        .background(UbiSky.gradient(for: .home))
}
