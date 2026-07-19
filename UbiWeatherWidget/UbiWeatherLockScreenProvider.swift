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
        Task {
            let entry = await refreshedEntry()
            // iOS treats this as a hint and budgets ~40-70 refreshes/day; the
            // read hits our cache, not KMA, so this costs no KMA quota.
            let nextReload = Calendar.current.date(byAdding: .minute, value: 15, to: Date())
                ?? Date().addingTimeInterval(900)
            completion(Timeline(entries: [entry], policy: .after(nextReload)))
        }
    }

    /// Widget-gallery preview / synchronous fallback — reads the last local snapshot.
    private func currentEntry() -> WidgetEntry {
        guard let snapshot = WidgetSharedStore.load() else {
            return WidgetEntry(date: Date(), content: .noLocation)
        }
        return WidgetEntry(date: Date(), content: .snapshot(snapshot))
    }

    /// Pulls the server-cached snapshot for this widget's grid. Falls back to
    /// the last local snapshot on any network failure so the widget never blanks.
    private func refreshedEntry() async -> WidgetEntry {
        guard let local = WidgetSharedStore.load() else {
            return WidgetEntry(date: Date(), content: .noLocation)
        }
        guard let nx = local.nx, let ny = local.ny,
              let remote = await WidgetRemote.fetch(nx: nx, ny: ny) else {
            return WidgetEntry(date: Date(), content: .snapshot(local))
        }
        let fresh = WidgetWeatherSnapshot(
            kind: remote.kind, line1: remote.line1, line2: remote.line2,
            accessibilityLabel: remote.accessibilityLabel, weatherCondition: remote.weatherCondition,
            updatedAt: Date(), nx: nx, ny: ny
        )
        WidgetSharedStore.save(fresh)  // keep for offline reuse
        return WidgetEntry(date: Date(), content: .snapshot(fresh))
    }
}
