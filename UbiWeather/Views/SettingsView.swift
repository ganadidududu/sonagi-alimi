import SwiftUI

struct SettingsView: View {
    @Bindable var vm: WeatherViewModel
    var onSetCurrentLocation: () -> Void = {}
    var onSelectRegion: (String) -> Void = { _ in }
    var onOpenRegionPicker: () -> Void = {}

    @State private var searchText = ""
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        ZStack {
            UbiSky.gradient(for: .settings).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("설정")
                        .font(UbiFont.screenTitle)
                        .foregroundStyle(Color(hex: 0x334A68))
                        .padding(.horizontal, 4)

                    regionSection
                    notificationSection
                    screenSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Region

    private var regionSection: some View {
        section(title: "지역") {
            VStack(spacing: 0) {
                Button(action: onSetCurrentLocation) {
                    Text("📍 현재 위치로 설정")
                        .font(UbiFont.pillLabel)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(UbiColors.primaryBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                .padding(.bottom, 6)

                // 시/도 → 시/군/구 picker (replaces the old free-text-only field,
                // which was easy to mistype and gave no sense of what's available).
                Button(action: onOpenRegionPicker) {
                    HStack(spacing: 9) {
                        Image(systemName: "list.bullet")
                            .foregroundStyle(UbiColors.primaryBlue)
                        Text("시·도에서 지역 고르기")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(UbiColors.textBody)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(UbiColors.textMuted2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                divider

                regionRow(name: vm.locationName, isCurrent: true, action: onSetCurrentLocation)
                ForEach(vm.savedRegions, id: \.self) { name in
                    regionRow(name: name, isCurrent: false, action: { onSelectRegion(name) })
                }
            }
            .padding(6)
        }
    }

    private func regionRow(name: String, isCurrent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(isCurrent ? "📍" : "☆")
                    .foregroundStyle(isCurrent ? UbiColors.primaryBlue : UbiColors.textMuted2)
                Text(name)
                    .font(.system(size: 13.5, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? UbiColors.textBody : UbiColors.textSub)
                Spacer()
                if isCurrent {
                    Text("현재")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(UbiColors.primaryBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func runSearch() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        searchFieldFocused = false
        onSelectRegion(query)
        searchText = ""
    }

    // MARK: Notifications

    private var notificationSection: some View {
        section(title: "알림") {
            VStack(spacing: 0) {
                toggleRow(icon: nil, title: "알림 받기", subtitle: "비 예보 시 푸시 알림", isOn: $vm.notifMasterOn)
                    .onChange(of: vm.notifMasterOn) { _, isOn in
                        guard isOn else { return }
                        Task { _ = await NotificationService.requestAuthorization() }
                    }
                divider
                toggleRow(icon: "🌦", title: "소나기 알림", subtitle: "2시간 내 소나기 예상 시", isOn: $vm.notifShowerOn)
                divider
                toggleRow(icon: "🌧", title: "비 알림", subtitle: "강수확률 60% 이상일 때", isOn: $vm.notifRainOn)
                divider
                toggleRow(icon: "🌙", title: "방해금지 시간", subtitle: "22:00 ~ 07:00 알림 끔", isOn: $vm.notifDndOn)
            }
        }
    }

    // MARK: Screen

    private var screenSection: some View {
        section(title: "화면") {
            toggleRow(icon: "🌗", title: "다크 모드", subtitle: "준비 중 · 곧 지원돼요", isOn: $vm.darkModeOn)
        }
    }

    // MARK: Shared building blocks

    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: 0x8195AD))
                .tracking(0.4)
                .padding(.horizontal, 4)

            content()
                .background(Color.white.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color(hex: 0x325078, opacity: 0.5), radius: 10, x: 0, y: 4)
        }
    }

    private func toggleRow(icon: String?, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            if let icon {
                Text(icon).font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(UbiColors.textBody)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(UbiColors.textMuted)
            }
            Spacer()
            UbiToggle(isOn: isOn)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
    }

    private var divider: some View {
        Rectangle().fill(UbiColors.divider).frame(height: 1).padding(.horizontal, 16)
    }
}

#Preview {
    SettingsView(vm: WeatherViewModel())
}
