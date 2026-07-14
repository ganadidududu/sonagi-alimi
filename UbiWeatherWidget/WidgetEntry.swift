import WidgetKit

struct WidgetEntry: TimelineEntry {
    enum Content {
        /// Widget gallery preview / before the app has ever written a snapshot's placeholder shape.
        case placeholder
        /// No shared snapshot yet — app never ran, or location permission was never granted.
        case noLocation
        case snapshot(WidgetWeatherSnapshot)
    }

    let date: Date
    let content: Content
}
