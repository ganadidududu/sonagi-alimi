import WidgetKit
import SwiftUI

@main
struct UbiWeatherWidgetBundle: WidgetBundle {
    var body: some Widget {
        UbiWeatherLockScreenWidget()
        HomeMediumWidget()
    }
}
