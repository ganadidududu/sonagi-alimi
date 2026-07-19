import WidgetKit

struct HomeWidgetEntry: TimelineEntry {
    enum Content {
        case placeholder
        case noLocation
        case snapshot(HomeWidgetSnapshot)
    }
    let date: Date
    let content: Content
}

/// Fetches the server-cached 6-slot snapshot for this widget's grid (same
/// `getWidgetWeather` endpoint as the lock-screen widget, `home` field) so it
/// auto-refreshes without opening the app — and without any device hitting KMA.
/// Falls back to the last local App Group snapshot on any network failure.
struct HomeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> HomeWidgetEntry {
        HomeWidgetEntry(date: Date(), content: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (HomeWidgetEntry) -> Void) {
        if context.isPreview {
            completion(HomeWidgetEntry(date: Date(), content: .placeholder))
            return
        }
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HomeWidgetEntry>) -> Void) {
        Task {
            let entry = await refreshedEntry()
            let nextReload = Calendar.current.date(byAdding: .minute, value: 15, to: Date())
                ?? Date().addingTimeInterval(900)
            completion(Timeline(entries: [entry], policy: .after(nextReload)))
        }
    }

    /// Gallery preview / synchronous fallback.
    private func currentEntry() -> HomeWidgetEntry {
        guard let snapshot = WidgetSharedStore.loadHome() else {
            return HomeWidgetEntry(date: Date(), content: .noLocation)
        }
        return HomeWidgetEntry(date: Date(), content: .snapshot(snapshot))
    }

    private func refreshedEntry() async -> HomeWidgetEntry {
        guard let local = WidgetSharedStore.loadHome() else {
            return HomeWidgetEntry(date: Date(), content: .noLocation)
        }
        guard let nx = local.nx, let ny = local.ny,
              let remote = await WidgetRemote.fetch(nx: nx, ny: ny),
              let home = remote.home else {
            return HomeWidgetEntry(date: Date(), content: .snapshot(local))
        }
        let fresh = HomeWidgetSnapshot(
            locationName: local.locationName,   // server only knows the grid; keep last name
            currentTemp: home.currentTemp,
            currentCondition: home.currentCondition,
            alert: home.alert.map { .init(kind: $0.kind, startText: $0.startText, minutesUntil: $0.minutesUntil) },
            slots: home.slots.map { .init(hourLabel: $0.hourLabel, temperature: $0.temperature, precipProbability: $0.precipProbability, condition: $0.condition) },
            updatedAt: Date(), nx: nx, ny: ny
        )
        WidgetSharedStore.saveHome(fresh)
        return HomeWidgetEntry(date: Date(), content: .snapshot(fresh))
    }
}
