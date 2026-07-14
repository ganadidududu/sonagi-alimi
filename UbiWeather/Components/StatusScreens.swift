import SwiftUI

// MARK: - Loading

struct LoadingSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ShimmerSkeleton(cornerRadius: 8).frame(width: 130, height: 22)
            ShimmerSkeleton(cornerRadius: 26).frame(height: 172)
            ShimmerSkeleton(cornerRadius: 24).frame(height: 118)
            ShimmerSkeleton(cornerRadius: 8).frame(width: 100, height: 18)
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    ShimmerSkeleton(cornerRadius: 22).frame(width: 78, height: 128)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 30)
    }
}

// MARK: - Error / no data

struct ErrorStateView: View {
    var onRetry: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            WeatherIconView(condition: .rain, size: 96, bob: true)
            Text("날씨를 불러오지 못했어요")
                .font(UbiFont.jua(22))
                .foregroundStyle(Color(hex: 0x33475F))
            Text("네트워크 연결을 확인한 뒤\n다시 시도해 주세요.")
                .font(.system(size: 13.5))
                .foregroundStyle(UbiColors.textDesc)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Button(action: onRetry) {
                Text("다시 시도")
                    .font(UbiFont.buttonLabel)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 13)
                    .background(UbiColors.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: UbiColors.primaryBlue.opacity(0.6), radius: 9, x: 0, y: 8)
            }
            .padding(.top, 8)
        }
        .padding(.top, 80)
        .padding(.horizontal, 34)
    }
}

// MARK: - Location permission denied

struct LocationDeniedView: View {
    var onRequestPermission: () -> Void = {}

    var body: some View {
        VStack(spacing: 15) {
            Text("📍").font(.system(size: 76))
            Text("위치 권한이 꺼져 있어요")
                .font(UbiFont.jua(22))
                .foregroundStyle(Color(hex: 0x33475F))
            Text("현재 위치 날씨를 보려면 권한이 필요해요.\n또는 지역을 직접 검색할 수 있어요.")
                .font(.system(size: 13.5))
                .foregroundStyle(UbiColors.textDesc)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(UbiColors.textMuted2)
                Text("동/읍/면으로 검색 (예: 마포구 서교동)")
                    .font(.system(size: 13.5))
                    .foregroundStyle(UbiColors.textMuted2)
                Spacer()
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color(hex: 0xDBE4EE), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: Color(hex: 0x3C5A82, opacity: 0.4), radius: 8, x: 0, y: 6)
            .padding(.top, 6)

            Button(action: onRequestPermission) {
                Text("📍 위치 권한 다시 요청")
                    .font(UbiFont.buttonLabel)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(UbiColors.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: UbiColors.primaryBlue.opacity(0.6), radius: 9, x: 0, y: 8)
            }
        }
        .padding(.top, 64)
        .padding(.horizontal, 30)
    }
}

// MARK: - Offline strip

struct OfflineStripView: View {
    let lastUpdated: String

    var body: some View {
        HStack(spacing: 9) {
            Circle().fill(UbiColors.warnDot).frame(width: 8, height: 8)
            Text("오프라인 · 마지막 업데이트 \(lastUpdated)")
                .font(.system(size: 12.5, weight: .semibold))
            Spacer()
            Text("캐시된 정보")
                .font(.system(size: 12.5))
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(UbiColors.offlineStrip)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
}

// MARK: - Notification permission priming
// Replaces the web reference's "PWA install" banner — there is no home-screen
// install concept natively, so this slot is repurposed to request
// UNUserNotificationCenter permission instead (per the handoff's platform notes).

struct NotificationPrimingBannerView: View {
    var onAllow: () -> Void = {}
    var onDismiss: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            Text("☂️").font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text("알림 켜고 비 소식 먼저 받기")
                    .font(UbiFont.pillLabel)
                Text("곧 올 비를 가장 먼저 알려드릴게요")
                    .font(.system(size: 12))
                    .opacity(0.82)
            }
            Spacer(minLength: 8)
            Button(action: onAllow) {
                Text("허용")
                    .font(UbiFont.jua(13))
                    .foregroundStyle(UbiColors.deepNavy)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(UbiColors.deepNavy)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color(hex: 0x1E3250, opacity: 0.6), radius: 15, x: 0, y: 14)
    }
}
