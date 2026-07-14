import Foundation
import CoreLocation
import WidgetKit

/// Fetches live KMA data, assembles it into the view models `HomeView`/`DailyView`
/// already render, and writes the result into `WeatherViewModel`. This is the
/// only place that knows about KMA's field/category quirks — everything
/// downstream just sees `HourlySlot`/`DailySummary`/`AlertLevel`.
@MainActor
final class WeatherRepository {
    private let vm: WeatherViewModel
    private let location: LocationService
    private var apiClient: KMAAPIClient?
    private var radarClient: RadarAPIClient?

    init(vm: WeatherViewModel, location: LocationService) {
        self.vm = vm
        self.location = location
    }

    /// Called once on app launch, and again on pull-to-refresh / "다시 시도".
    func refresh() async {
        guard !Secrets.kmaServiceKey.isEmpty, Secrets.kmaServiceKey != "YOUR_KMA_SERVICE_KEY" else {
            vm.screenState = .error
            return
        }
        if apiClient == nil {
            apiClient = KMAAPIClient(serviceKey: Secrets.kmaServiceKey)
        }

        if location.isDenied {
            vm.screenState = .locationDenied
            return
        }

        vm.screenState = .loading
        do {
            let coordinate = try await location.requestLocation()
            try await load(coordinate: coordinate, displayName: "내 위치")
            let notifStatus = await NotificationService.authorizationStatus()
            vm.screenState = notifStatus == .notDetermined ? .notificationPriming : .normal
        } catch is CLError {
            vm.screenState = .locationDenied
        } catch {
            vm.screenState = .error
        }
    }

    /// Settings → "동/읍/면 검색" or tapping a saved region. Geocodes the name
    /// with `CLGeocoder` (no separate API/key needed) and re-runs the same
    /// pipeline as GPS, just anchored to that place instead of the device's
    /// live location — matches the PRD's "지역명 검색으로 nx/ny 선택" fallback.
    func selectRegion(named query: String) async {
        guard !Secrets.kmaServiceKey.isEmpty, Secrets.kmaServiceKey != "YOUR_KMA_SERVICE_KEY" else {
            vm.screenState = .error
            return
        }
        if apiClient == nil {
            apiClient = KMAAPIClient(serviceKey: Secrets.kmaServiceKey)
        }

        vm.screenState = .loading
        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(query + ", 대한민국")
            guard let coordinate = placemarks.first?.location?.coordinate else {
                vm.screenState = .error
                return
            }
            try await load(coordinate: coordinate, displayName: query)
            let notifStatus = await NotificationService.authorizationStatus()
            vm.screenState = notifStatus == .notDetermined ? .notificationPriming : .normal
        } catch {
            vm.screenState = .error
        }
    }

    private func load(coordinate: CLLocationCoordinate2D, displayName: String) async throws {
        guard let client = apiClient else { return }
        let grid = GridConverter.toGrid(coordinate: coordinate)
        NotificationPreferences.setLastGrid(nx: grid.nx, ny: grid.ny)
        PushRegistrationService.shared.updateGrid(nx: grid.nx, ny: grid.ny)
        let now = Date()

        async let ncstItems = client.ultraSrtNcst(nx: grid.nx, ny: grid.ny, now: now)
        async let fcstItems = client.ultraSrtFcst(nx: grid.nx, ny: grid.ny, now: now)
        async let vilageItems = client.vilageFcst(nx: grid.nx, ny: grid.ny, now: now)

        let (ncst, fcst, vilage) = try await (ncstItems, fcstItems, vilageItems)

        applyCurrentConditions(ncst)
        let slots = applyHourly(fcst, now: now)
        applyAlertBanner(slots: slots, now: now)
        applyDaily(vilage)
        vm.locationName = displayName
        vm.lastUpdatedLabel = "방금 업데이트"
        updateWidgetSnapshot()

        if let alert = KMAParsing.evaluateAlert(slots: slots, now: now) {
            await NotificationService.postIfNeeded(alert)
        }
    }

    // MARK: - Lock-screen widget snapshot (App Group hand-off)

    /// Mirrors `vm.alertLevel`/`vm.currentTemperature`/`vm.currentIcon` into the
    /// shared snapshot the widget reads — no separate alert logic, so the
    /// widget can never show something the Home banner disagrees with.
    private func updateWidgetSnapshot() {
        let snapshot: WidgetWeatherSnapshot
        switch vm.alertLevel {
        case .shower(let windowText, let minutesUntil):
            snapshot = WidgetWeatherSnapshot(
                kind: .shower,
                line1: "소나기 임박",
                line2: widgetLine2(windowText: windowText, minutesUntil: minutesUntil),
                accessibilityLabel: "\(widgetMinutesPrefix(minutesUntil))\(widgetA11yWindowPhrase(windowText)) 소나기가 예상됩니다",
                weatherCondition: WeatherCondition.shower.rawValue,
                updatedAt: Date()
            )
        case .rain(let windowText, let minutesUntil):
            snapshot = WidgetWeatherSnapshot(
                kind: .rain,
                line1: "비 예정",
                line2: widgetLine2(windowText: windowText, minutesUntil: minutesUntil),
                accessibilityLabel: "\(widgetMinutesPrefix(minutesUntil))\(widgetA11yWindowPhrase(windowText)) 비가 예상됩니다",
                weatherCondition: WeatherCondition.rain.rawValue,
                updatedAt: Date()
            )
        case .none:
            snapshot = WidgetWeatherSnapshot(
                kind: .calm,
                line1: "비 걱정 없어요",
                line2: "\(vm.currentTemperature)° · \(vm.currentIcon.label)",
                accessibilityLabel: "오늘 강수확률이 낮아 비 걱정이 없습니다. 현재 기온 \(vm.currentTemperature)도, \(vm.currentIcon.label)",
                weatherCondition: vm.currentIcon.rawValue,
                updatedAt: Date()
            )
        }
        WidgetSharedStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: "UbiWeatherLockScreenWidget")
    }

    /// `KMAParsing.koreanHourRange` repeats "오전/오후" on both ends (e.g. "오후
    /// 3시~오후 4시"); the widget's ~16자 budget only fits it stated once, which
    /// is also how the design spec's own example ("오후 3시~4시 · 13분 후") reads.
    private func widgetLine2(windowText: String, minutesUntil: Int) -> String {
        let compact = widgetCompactWindowText(windowText)
        return minutesUntil > 60 ? compact : "\(compact) · \(minutesUntil)분 후"
    }

    private func widgetCompactWindowText(_ text: String) -> String {
        let parts = text.components(separatedBy: "~")
        guard parts.count == 2 else { return text }
        for period in ["오전 ", "오후 "] where parts[0].hasPrefix(period) && parts[1].hasPrefix(period) {
            return parts[0] + "~" + parts[1].dropFirst(period.count)
        }
        return text
    }

    /// "오후 3시~오후 4시" -> "오후 3시부터 4시까지" for the VoiceOver sentence.
    private func widgetA11yWindowPhrase(_ text: String) -> String {
        let parts = text.components(separatedBy: "~")
        guard parts.count == 2 else { return text }
        let end = parts[1]
            .replacingOccurrences(of: "오전 ", with: "")
            .replacingOccurrences(of: "오후 ", with: "")
        return "\(parts[0])부터 \(end)까지"
    }

    private func widgetMinutesPrefix(_ minutesUntil: Int) -> String {
        minutesUntil > 60 ? "" : "\(minutesUntil)분 후 "
    }

    // MARK: - Radar tab (`getCmpImg`) — loaded lazily when the tab is opened

    /// Uses the same data.go.kr service key as the weather endpoints — you
    /// still need to separately apply for "레이더영상 조회서비스" approval
    /// on data.go.kr, but approved products share one key.
    func loadRadar() async {
        guard !Secrets.kmaServiceKey.isEmpty, Secrets.kmaServiceKey != "YOUR_KMA_SERVICE_KEY" else {
            vm.radarLoadState = .error("서비스 키를 설정해 주세요.")
            return
        }
        if radarClient == nil {
            radarClient = RadarAPIClient(serviceKey: Secrets.kmaServiceKey)
        }
        guard let client = radarClient else { return }

        vm.radarLoadState = .loading
        do {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
            let df = DateFormatter()
            df.dateFormat = "yyyyMMdd"
            df.timeZone = cal.timeZone
            let today = df.string(from: Date())

            var frames = try await client.compositeFrames(date: today)
            if frames.isEmpty {
                // Radar only covers "the last 2 days" — before dawn, today's
                // run may not have any frames yet, so fall back to yesterday.
                let yesterday = df.string(from: cal.date(byAdding: .day, value: -1, to: Date())!)
                frames = try await client.compositeFrames(date: yesterday)
            }

            guard !frames.isEmpty else {
                vm.radarLoadState = .error("레이더 영상이 아직 없어요.")
                return
            }
            vm.radarFrames = frames
            vm.radarFrameIndex = frames.count - 1
            vm.radarLoadState = .loaded
        } catch {
            vm.radarLoadState = .error((error as? KMAError)?.message ?? "레이더 영상을 불러오지 못했어요.")
        }
    }

    // MARK: - getUltraSrtNcst → current readings

    private func applyCurrentConditions(_ items: [KMAItem]) {
        var byCategory: [String: KMAItem] = [:]
        for item in items { byCategory[item.category] = item }

        if let t1h = byCategory["T1H"]?.doubleValue { vm.currentTemperature = Int(t1h.rounded()) }
        if let reh = byCategory["REH"]?.intValue { vm.humidityPercent = reh }
        if let wsd = byCategory["WSD"]?.doubleValue { vm.windSpeed = String(format: "%.1f㎧", wsd) }
    }

    // MARK: - getUltraSrtFcst → 6h timeline + "now" summary

    /// Returns the parsed slots (also consumed by `applyAlertBanner`).
    @discardableResult
    private func applyHourly(_ items: [KMAItem], now: Date) -> [HourlySlot] {
        let slots = KMAParsing.parseHourlySlots(items)
        vm.hourly = slots
        if let first = slots.first {
            vm.currentIcon = first.condition
            vm.currentSummaryLabel = first.conditionLabel
            vm.precipProbability = first.precipProbability
        }
        vm.peakPrecipWindowText = peakPrecipWindowText(slots: slots, now: now)
        return slots
    }

    /// Mirrors the Hourly tab's summary banner in the reference design —
    /// "OO시~PP시 강수확률이 가장 높아요 (NN%)" for whichever slot peaks, but
    /// when every slot is low that framing reads as a false alarm every day
    /// (Seoul often sits at 20~30% all day with no rain), so below the same
    /// 30% floor used to call a slot "showery" we swap in a reassurance line.
    private func peakPrecipWindowText(slots: [HourlySlot], now: Date) -> String {
        guard let peak = slots.max(by: { $0.precipProbability < $1.precipProbability }) else {
            return ""
        }
        guard peak.precipProbability >= 30 else {
            return "오늘은 강수확률이 낮아요 · 비 걱정 없어요 (최고 \(peak.precipProbability)%)"
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let currentHour = cal.component(.hour, from: now)
        let startHour = Int(peak.hourLabel.replacingOccurrences(of: "시", with: "")) ?? currentHour
        let endHour = (startHour + 1) % 24
        return "\(startHour)시~\(endHour)시 강수확률이 가장 높아요 (\(peak.precipProbability)%)"
    }

    // MARK: - Alert banner (killer feature): next 2h window from the timeline

    private func applyAlertBanner(slots: [HourlySlot], now: Date) {
        guard let result = KMAParsing.evaluateAlert(slots: slots, now: now) else {
            vm.alertLevel = .none
            return
        }
        vm.bannerIcon = result.icon
        vm.alertLevel = result.level
    }

    // MARK: - getVilageFcst → daily summaries (today + however many days KMA returns)

    private func applyDaily(_ items: [KMAItem]) {
        var byDate: [String: [String: [KMAItem]]] = [:]  // date -> category -> items
        for item in items {
            guard let date = item.fcstDate else { continue }
            byDate[date, default: [:]][item.category, default: []].append(item)
        }

        let today = KMABaseTime.vilageFcst().date
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        df.timeZone = cal.timeZone

        let days = byDate.keys.sorted().compactMap { date -> DailySummary? in
            guard let categories = byDate[date] else { return nil }
            let tmn = categories["TMN"]?.first?.intValue
            let tmx = categories["TMX"]?.first?.intValue
            let allTemps = categories["TMP"]?.compactMap(\.intValue) ?? []
            let low = tmn ?? allTemps.min()
            let high = tmx ?? allTemps.max()
            guard let low, let high else { return nil }

            // Representative sky/pty: the slot closest to solar noon.
            let noonSlot = categories["SKY"]?.min { a, b in
                distanceFromNoon(a.fcstTime) < distanceFromNoon(b.fcstTime)
            }
            let sky = noonSlot?.intValue
            let pty = categories["PTY"]?.first { $0.fcstTime == noonSlot?.fcstTime }?.intValue ?? 0
            let pop = categories["POP"]?.compactMap(\.intValue).max() ?? 0

            let isToday = date == today
            let dayLabel = koreanDayLabel(date: date, today: today, formatter: df, calendar: cal)
            let dateLabel = "\(Int(date.dropFirst(4).prefix(2)) ?? 0)/\(Int(date.suffix(2)) ?? 0)"

            return DailySummary(
                dayLabel: dayLabel, dateLabel: dateLabel,
                condition: weatherCondition(pty: pty, sky: sky),
                conditionLabel: conditionLabel(pty: pty, sky: sky),
                precipProbability: pop, low: low, high: high, isToday: isToday
            )
        }

        vm.weekly = days
        vm.threeDay = Array(days.prefix(3))
    }

    private func distanceFromNoon(_ fcstTime: String?) -> Int {
        guard let hour = fcstTime.flatMap({ Int($0.prefix(2)) }) else { return .max }
        return abs(hour - 13)
    }

    private func koreanDayLabel(date: String, today: String, formatter: DateFormatter, calendar: Calendar) -> String {
        guard let todayDate = formatter.date(from: today), let thisDate = formatter.date(from: date) else { return date }
        let dayDiff = calendar.dateComponents([.day], from: todayDate, to: thisDate).day ?? 0
        switch dayDiff {
        case 0: return "오늘"
        case 1: return "내일"
        case 2: return "모레"
        default:
            let symbols = ["일", "월", "화", "수", "목", "금", "토"]
            let weekday = calendar.component(.weekday, from: thisDate) - 1
            return symbols[weekday]
        }
    }
}
