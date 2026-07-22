import SwiftUI
import UIKit

/// Full-screen hard-update wall. Shown when the installed version is below the
/// server's `minSupported` — there's no dismiss, only "App Store로 이동". Use
/// sparingly (broken old builds, incompatible server changes); a gate with no
/// real reason just annoys people and risks App Review rejection.
struct UpdateGateView: View {
    let storeURL: String

    var body: some View {
        ZStack {
            UbiSky.gradient(for: .home).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("🌧️").font(.system(size: 64))

                Text("업데이트가 필요해요")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(hex: 0x2F4A6D))

                Text("이 버전은 더 이상 지원되지 않아요.\n최신 버전으로 업데이트하면 계속 사용할 수 있어요.")
                    .font(.system(size: 14))
                    .foregroundStyle(UbiColors.textSub)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Button {
                    if let url = URL(string: storeURL) { UIApplication.shared.open(url) }
                } label: {
                    Text("App Store에서 업데이트")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(UbiColors.primaryBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.top, 8)
            }
            .padding(28)
            .padding(.horizontal, 12)
        }
    }
}

/// Dismissible "새 버전 있어요" strip for the soft case. Sits at the top of the
/// home screen; tapping the button opens the App Store, tapping ✕ hides it for
/// this launch.
struct UpdateBanner: View {
    let latest: String
    let storeURL: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("🎉").font(.system(size: 16))
            VStack(alignment: .leading, spacing: 1) {
                Text("새 버전 \(latest)이 나왔어요")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: 0x2F4A6D))
                Text("업데이트하면 새 기능을 쓸 수 있어요")
                    .font(.system(size: 11))
                    .foregroundStyle(UbiColors.textSub)
            }
            Spacer()
            Button("업데이트") {
                if let url = URL(string: storeURL) { UIApplication.shared.open(url) }
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(UbiColors.primaryBlue)
            .clipShape(Capsule())

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(UbiColors.textMuted2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.7), lineWidth: 1))
        .padding(.horizontal, 12)
    }
}
