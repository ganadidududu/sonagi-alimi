import SwiftUI

struct ContentView: View {
    @State private var vm = WeatherViewModel()
    @State private var locationService = LocationService()
    @State private var repository: WeatherRepository?

    var body: some View {
        TabView(selection: $vm.selectedTab) {
            ForEach(UbiTab.allCases) { tab in
                screen(for: tab)
                    .tabItem {
                        Label(tab.label, systemImage: tab.systemImage)
                    }
                    .tag(tab)
            }
        }
        .tint(UbiColors.primaryBlue)
        .task {
            let repo = repository ?? WeatherRepository(vm: vm, location: locationService)
            repository = repo
            await repo.refresh()
        }
        .onOpenURL { url in
            // Lock-screen widget's "위치를 설정해 주세요" state links here (widget spec §11).
            if url.host == "settings" { vm.selectedTab = .settings }
        }
    }

    @ViewBuilder
    private func screen(for tab: UbiTab) -> some View {
        switch tab {
        case .home:
            HomeView(
                vm: vm,
                onRetry: { Task { await refresh() } },
                onRequestLocationPermission: { locationService.requestPermission() }
            )
        case .hourly: HourlyView(vm: vm)
        case .daily: DailyView(vm: vm)
        case .radar:
            RadarView(vm: vm, onLoad: { await loadRadar() })
        case .settings:
            SettingsView(
                vm: vm,
                onSetCurrentLocation: { Task { await refresh() } },
                onSelectRegion: { name in Task { await selectRegion(name) } }
            )
        }
    }

    private func refresh() async {
        let repo = repository ?? WeatherRepository(vm: vm, location: locationService)
        repository = repo
        await repo.refresh()
    }

    private func selectRegion(_ name: String) async {
        let repo = repository ?? WeatherRepository(vm: vm, location: locationService)
        repository = repo
        await repo.selectRegion(named: name)
    }

    private func loadRadar() async {
        let repo = repository ?? WeatherRepository(vm: vm, location: locationService)
        repository = repo
        await repo.loadRadar()
    }
}

#Preview {
    ContentView()
}
