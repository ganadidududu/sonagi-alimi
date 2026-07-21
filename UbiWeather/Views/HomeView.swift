import SwiftUI

struct HomeView: View {
    @Bindable var vm: WeatherViewModel
    var onRetry: () -> Void = {}
    var onRequestLocationPermission: () -> Void = {}
    var onOpenRegionPicker: () -> Void = {}
    /// Soft update banner data, when a newer (but non-mandatory) version exists.
    var softUpdate: (latest: String, storeURL: String)? = nil
    var onDismissUpdate: () -> Void = {}

    private var showsTabContent: Bool {
        switch vm.screenState {
        case .normal, .offline, .notificationPriming: return true
        case .loading, .error, .locationDenied: return false
        }
    }

    private var skyGradient: LinearGradient {
        switch vm.screenState {
        case .loading, .error, .locationDenied: return UbiSky.gradient(for: nil)
        default: return UbiSky.gradient(for: .home)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            skyGradient.ignoresSafeArea()

            if vm.rainAnimationEnabled && showsTabContent {
                RainOverlayView()
            }

            VStack(spacing: 0) {
                if let soft = softUpdate {
                    UpdateBanner(latest: soft.latest, storeURL: soft.storeURL, onDismiss: onDismissUpdate)
                        .padding(.top, 8)
                }
                if case .offline(let lastUpdated) = vm.screenState {
                    OfflineStripView(lastUpdated: lastUpdated)
                }

                ScrollView {
                    Group {
                        switch vm.screenState {
                        case .loading:
                            LoadingSkeletonView()
                        case .error:
                            ErrorStateView(onRetry: onRetry)
                        case .locationDenied:
                            LocationDeniedView(onRequestPermission: onRequestLocationPermission)
                        case .normal, .offline, .notificationPriming:
                            homeContent
                        }
                    }
                    .padding(.top, 10)
                }
                .scrollIndicators(.hidden)
                .refreshable { onRetry() }
            }
        }
    }

    private var homeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            locationHeader

            AlertBannerView(level: vm.alertLevel, icon: vm.bannerIcon, accent: vm.accent)

            CurrentWeatherCardView(
                temperature: vm.currentTemperature,
                summaryLabel: vm.currentSummaryLabel,
                icon: vm.currentIcon,
                humidityPercent: vm.humidityPercent,
                windSpeed: vm.windSpeed,
                precipProbability: vm.precipProbability
            )

            HourlyPreviewSection(slots: vm.hourly, onSeeMore: vm.goToHourly)

            ThreeDaySummarySection(days: vm.threeDay)

            if case .notificationPriming = vm.screenState {
                NotificationPrimingBannerView(
                    onAllow: {
                        Task {
                            _ = await NotificationService.requestAuthorization()
                            vm.screenState = .normal
                        }
                    },
                    onDismiss: { vm.screenState = .normal }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private var locationHeader: some View {
        HStack {
            // The chevron used to be decoration only — it now opens the region
            // picker, which is what users expect from a location + caret.
            Button(action: onOpenRegionPicker) {
                HStack(spacing: 5) {
                    Text("📍 \(vm.locationName)")
                        .font(UbiFont.locationHeader)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11))
                        .opacity(0.6)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            Button(action: onRetry) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                    Text(lastUpdatedText)
                        .font(.system(size: 12))
                }
                .opacity(0.7)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(UbiColors.textStrong)
    }

    private var lastUpdatedText: String {
        if case .offline = vm.screenState { return "오프라인" }
        return vm.lastUpdatedLabel
    }
}

#Preview("Normal") {
    HomeView(vm: WeatherViewModel())
}

#Preview("Loading") {
    let vm = WeatherViewModel()
    vm.screenState = .loading
    return HomeView(vm: vm)
}

#Preview("Offline") {
    let vm = WeatherViewModel()
    vm.screenState = .offline(lastUpdated: "14:32")
    return HomeView(vm: vm)
}

#Preview("Error") {
    let vm = WeatherViewModel()
    vm.screenState = .error
    return HomeView(vm: vm)
}

#Preview("Location Denied") {
    let vm = WeatherViewModel()
    vm.screenState = .locationDenied
    return HomeView(vm: vm)
}

#Preview("Notification Priming") {
    let vm = WeatherViewModel()
    vm.screenState = .notificationPriming
    return HomeView(vm: vm)
}
