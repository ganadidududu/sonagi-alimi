import WidgetKit

/// Reads whatever `WeatherRepository` last wrote to the App Group — this
/// provider never calls KMA itself (spec §9). `getTimeline`'s reload window
/// is only a safety-net fallback; the real refresh trigger is
/// `WidgetCenter.shared.reloadTimelines` fired by the app after every fetch.
struct UbiWeatherLockScreenProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), content: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        if context.isPreview {
            completion(WidgetEntry(date: Date(), content: .placeholder))
            return
        }
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = currentEntry()
        let fallbackReload = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(fallbackReload)))
    }

    private func currentEntry() -> WidgetEntry {
        guard let snapshot = WidgetSharedStore.load() else {
            return WidgetEntry(date: Date(), content: .noLocation)
        }
        return WidgetEntry(date: Date(), content: .snapshot(snapshot))
    }
}
