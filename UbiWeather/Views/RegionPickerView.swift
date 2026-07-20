import SwiftUI

/// 시/도 → 시/군/구 two-step picker. Replaces the old free-text-only search:
/// tapping a district hands the repository the full address to geocode plus a
/// compact label to display, and the choice is pinned (see `LocationPreference`).
struct RegionPickerView: View {
    /// (geocodeQuery, displayName) — e.g. ("서울특별시 강남구", "서울 강남구")
    var onSelect: (String, String) -> Void
    var onUseCurrentLocation: () -> Void
    var onClose: () -> Void

    @State private var selectedProvince: KoreaRegions.Province?
    @State private var searchText = ""

    var body: some View {
        ZStack {
            UbiSky.gradient(for: .settings).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if searchText.isEmpty {
                    if let province = selectedProvince {
                        districtList(province)
                    } else {
                        provinceList
                    }
                } else {
                    searchResults
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                if selectedProvince != nil && searchText.isEmpty {
                    Button {
                        selectedProvince = nil
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                            Text("시·도")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(UbiColors.primaryBlue)
                    }
                } else {
                    Spacer().frame(width: 44)
                }
                Spacer()
                Text(selectedProvince?.name ?? "지역 선택")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(UbiColors.textStrong)
                Spacer()
                Button("닫기", action: onClose)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(UbiColors.textSub)
            }

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(UbiColors.textMuted2)
                TextField("지역 검색 (예: 강남구)", text: $searchText)
                    .font(.system(size: 14))
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(Color.white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Button(action: onUseCurrentLocation) {
                Text("📍 현재 위치로 설정")
                    .font(UbiFont.pillLabel)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(UbiColors.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(16)
    }

    // MARK: Lists

    private var provinceList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(KoreaRegions.all) { province in
                    Button { selectedProvince = province } label: {
                        HStack {
                            Text(province.name)
                                .font(.system(size: 15))
                                .foregroundStyle(UbiColors.textBody)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(UbiColors.textMuted2)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    divider
                }
            }
            .background(Color.white.opacity(0.62))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private func districtList(_ province: KoreaRegions.Province) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(province.districts, id: \.self) { district in
                    Button {
                        onSelect(KoreaRegions.geocodeQuery(province: province, district: district),
                                 KoreaRegions.displayName(province: province, district: district))
                    } label: {
                        HStack {
                            Text(district)
                                .font(.system(size: 15))
                                .foregroundStyle(UbiColors.textBody)
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    divider
                }
            }
            .background(Color.white.opacity(0.62))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    /// Flat search across every 시/도 + 시/군/구.
    private var searchResults: some View {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        let matches: [(KoreaRegions.Province, String)] = KoreaRegions.all.flatMap { province in
            province.districts
                .filter { $0.contains(q) || province.name.contains(q) || province.short.contains(q) }
                .map { (province, $0) }
        }
        return ScrollView {
            if matches.isEmpty {
                Text("검색 결과가 없어요")
                    .font(.system(size: 14))
                    .foregroundStyle(UbiColors.textMuted)
                    .padding(.top, 40)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(matches.enumerated()), id: \.offset) { _, pair in
                        Button {
                            onSelect(KoreaRegions.geocodeQuery(province: pair.0, district: pair.1),
                                     KoreaRegions.displayName(province: pair.0, district: pair.1))
                        } label: {
                            HStack {
                                Text(KoreaRegions.displayName(province: pair.0, district: pair.1))
                                    .font(.system(size: 15))
                                    .foregroundStyle(UbiColors.textBody)
                                Spacer()
                                Text(pair.0.name)
                                    .font(.system(size: 12))
                                    .foregroundStyle(UbiColors.textMuted2)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        divider
                    }
                }
                .background(Color.white.opacity(0.62))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(UbiColors.divider).frame(height: 1).padding(.horizontal, 16)
    }
}
