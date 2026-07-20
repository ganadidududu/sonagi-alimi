import SwiftUI
import UIKit

struct ContentView: View {
    @State private var vm = WeatherViewModel()
    @State private var locationService = LocationService()
    @State private var repository: WeatherRepository?
    @State private var showingRegionPicker = false

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
        .sheet(isPresented: $showingRegionPicker) {
            RegionPickerView(
                onSelect: { query, display in
                    showingRegionPicker = false
                    Task { await selectRegion(query, displayName: display) }
                },
                onUseCurrentLocation: {
                    showingRegionPicker = false
                    Task { await useCurrentLocation() }
                },
                onClose: { showingRegionPicker = false }
            )
        }
    }

    @ViewBuilder
    private func screen(for tab: UbiTab) -> some View {
        switch tab {
        case .home:
            HomeView(
                vm: vm,
                onRetry: { Task { await refresh() } },
                onRequestLocationPermission: { Task { await requestLocationPermission() } },
                onOpenRegionPicker: { showingRegionPicker = true }
            )
        case .hourly: HourlyView(vm: vm)
        case .daily: DailyView(vm: vm)
        case .radar:
            RadarView(vm: vm, onLoad: { await loadRadar() })
        case .settings:
            SettingsView(
                vm: vm,
                onSetCurrentLocation: { Task { await useCurrentLocation() } },
                onSelectRegion: { name in Task { await selectRegion(name) } },
                onOpenRegionPicker: { showingRegionPicker = true }
            )
        }
    }

    private func refresh() async {
        let repo = repository ?? WeatherRepository(vm: vm, location: locationService)
        repository = repo
        await repo.refresh()
    }

    private func selectRegion(_ name: String, displayName: String? = nil) async {
        let repo = repository ?? WeatherRepository(vm: vm, location: locationService)
        repository = repo
        await repo.selectRegion(named: name, displayName: displayName)
    }

    /// "위치 권한 허용" on the permission screen. Waits for the prompt's answer
    /// and then retries the load, so the screen advances without a relaunch.
    /// Once denied, iOS won't prompt again — send the user to Settings instead.
    private func requestLocationPermission() async {
        if locationService.isDenied {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                await UIApplication.shared.open(url)
            }
            return
        }
        await locationService.requestPermissionAndWait()
        await refresh()
    }

    private func useCurrentLocation() async {
        let repo = repository ?? WeatherRepository(vm: vm, location: locationService)
        repository = repo
        await repo.useCurrentLocation()
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
