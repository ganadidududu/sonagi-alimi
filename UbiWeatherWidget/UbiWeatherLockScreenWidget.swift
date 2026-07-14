import SwiftUI
import WidgetKit

struct UbiWeatherLockScreenWidget: Widget {
    static let kind = "UbiWeatherLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: UbiWeatherLockScreenProvider()) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("소나기 알리미")
        .description("2시간 내 소나기·비 예보를 잠금화면에서 바로 확인해요.")
        .supportedFamilies([.accessoryRectangular])
    }
}
