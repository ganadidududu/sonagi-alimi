import SwiftUI
import WidgetKit

struct HomeMediumWidget: Widget {
    static let kind = "UbiWeatherHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: HomeWidgetProvider()) { entry in
            HomeWidgetView(entry: entry)
        }
        .configurationDisplayName("6시간 예보")
        .description("현재 날씨와 앞으로 6시간 시간별 예보를 홈 화면에서 바로 확인해요.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview("A · 소나기 임박", as: .systemMedium) {
    HomeMediumWidget()
} timeline: {
    HomeWidgetEntry(date: .now, content: .snapshot(HomeWidgetSnapshot(
        locationName: "마포구 서교동", currentTemp: 26, currentCondition: "cloudy",
        alert: .init(kind: .shower, startText: "오후 3시~4시", minutesUntil: 13),
        slots: [
            .init(hourLabel: "지금", temperature: 26, precipProbability: 20, condition: "cloudy"),
            .init(hourLabel: "15시", temperature: 25, precipProbability: 80, condition: "shower"),
            .init(hourLabel: "16시", temperature: 24, precipProbability: 75, condition: "shower"),
            .init(hourLabel: "17시", temperature: 24, precipProbability: 55, condition: "rain"),
            .init(hourLabel: "18시", temperature: 25, precipProbability: 20, condition: "cloudy"),
            .init(hourLabel: "19시", temperature: 26, precipProbability: 10, condition: "partly"),
        ],
        updatedAt: .now
    )))
}

#Preview("C · 평상시", as: .systemMedium) {
    HomeMediumWidget()
} timeline: {
    HomeWidgetEntry(date: .now, content: .snapshot(HomeWidgetSnapshot(
        locationName: "마포구 서교동", currentTemp: 26, currentCondition: "cloudy",
        alert: nil,
        slots: [
            .init(hourLabel: "지금", temperature: 26, precipProbability: 20, condition: "partly"),
            .init(hourLabel: "15시", temperature: 27, precipProbability: 10, condition: "partly"),
            .init(hourLabel: "16시", temperature: 28, precipProbability: 0, condition: "sunny"),
            .init(hourLabel: "17시", temperature: 27, precipProbability: 0, condition: "sunny"),
            .init(hourLabel: "18시", temperature: 26, precipProbability: 20, condition: "partly"),
            .init(hourLabel: "19시", temperature: 25, precipProbability: 30, condition: "cloudy"),
        ],
        updatedAt: .now
    )))
}
