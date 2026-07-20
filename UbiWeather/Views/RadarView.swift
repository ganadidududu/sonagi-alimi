import SwiftUI

struct RadarView: View {
    @Bindable var vm: WeatherViewModel
    var onLoad: () async -> Void = {}

    @State private var isPlaying = false
    @State private var playbackTask: Task<Void, Never>?

    @State private var zoomScale: CGFloat = 1
    @State private var committedZoomScale: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @State private var committedPanOffset: CGSize = .zero

    private let minZoom: CGFloat = 1
    private let maxZoom: CGFloat = 6

    var body: some View {
        ZStack {
            UbiSky.gradient(for: .radar).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("강수 레이더")
                        .font(UbiFont.screenTitle)
                        .foregroundStyle(Color(hex: 0x334A68))
                        .padding(.horizontal, 4)

                    mapCard
                    legend
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .task { await onLoad() }
        .onDisappear { stopPlayback() }
    }

    @ViewBuilder
    private var mapCard: some View {
        switch vm.radarLoadState {
        case .idle, .loading:
            radarFrame { LoadingSkeletonPatch() }
        case .error(let message):
            radarFrame {
                VStack(spacing: 10) {
                    WeatherIconView(condition: .rain, size: 56)
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(UbiColors.textDesc)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
        case .loaded:
            radarFrame {
                GeometryReader { geo in
                    ZStack {
                        if let frame = vm.radarCurrentFrame {
                            AsyncImage(url: frame.url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                case .failure:
                                    Color(hex: 0xC3D3E2)
                                default:
                                    Color(hex: 0xDBE6F0)
                                }
                            }
                            // `scaledToFill` reports a size WIDER than the card,
                            // which would size the ZStack — and with it the
                            // playback bar — past the rounded edge, clipping the
                            // clock off. Pin the image's layout size to the
                            // container so only its pixels overflow (the outer
                            // `.clipped()` still trims those).
                            .frame(width: geo.size.width, height: geo.size.height)
                            .scaleEffect(zoomScale)
                            .offset(panOffset)
                            .gesture(magnifyGesture(containerSize: geo.size))
                            // Only claims the drag once zoomed — otherwise the
                            // page's own ScrollView needs it to scroll normally.
                            .gesture(panGesture(containerSize: geo.size), including: zoomScale > 1.01 ? .all : .subviews)
                            .onTapGesture(count: 2) { resetZoom() }
                        }
                        VStack {
                            Spacer()
                            playbackBar.padding(12)
                        }
                        if zoomScale > 1.01 {
                            zoomResetHint
                        }
                    }
                    .clipped()
                }
            }
        }
    }

    private func radarFrame(@ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .frame(height: 400)
            .background(LinearGradient(colors: [Color(hex: 0xDBE6F0), Color(hex: 0xC3D3E2)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color(hex: 0x325078, opacity: 0.5), radius: 14, x: 0, y: 6)
    }

    private var playbackBar: some View {
        HStack(spacing: 11) {
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(UbiColors.primaryBlue)
                    .clipShape(Circle())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: 0xDBE4EE)).frame(height: 5)
                    Capsule().fill(UbiColors.primaryBlue)
                        .frame(width: geo.size.width * vm.radarProgress, height: 5)
                    Circle()
                        .fill(.white)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(UbiColors.primaryBlue, lineWidth: 2))
                        .offset(x: geo.size.width * vm.radarProgress - 6)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { value in
                        scrub(to: value.location.x, width: geo.size.width)
                    }
                )
            }
            .frame(height: 20)

            // Jua is wider than the system font, so "15:20" overflowed the old
            // fixed 48pt and clipped its right edge. Size to the text and give
            // it layout priority so the scrubber (not the clock) absorbs the
            // leftover width; minWidth keeps the bar from twitching as digits
            // change during playback.
            Text(vm.radarTimeLabel)
                .font(UbiFont.jua(13))
                .foregroundStyle(UbiColors.textBody)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 48, alignment: .trailing)
                .layoutPriority(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var legend: some View {
        HStack(spacing: 8) {
            Text("약함").font(.system(size: 11, weight: .semibold))
            LinearGradient(colors: [Color(hex: 0xBFE0F7), Color(hex: 0x4A90E2), Color(hex: 0xF4A13C), Color(hex: 0xE5533D)], startPoint: .leading, endPoint: .trailing)
                .frame(height: 8)
                .clipShape(Capsule())
            Text("강함").font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(Color(hex: 0x7C8EA3))
        .padding(.horizontal, 4)
    }

    // MARK: - Pinch-zoom / pan

    private var zoomResetHint: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: resetZoom) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(9)
                        .background(Color.black.opacity(0.35))
                        .clipShape(Circle())
                }
                .padding(10)
            }
            Spacer()
        }
    }

    private func magnifyGesture(containerSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoomScale = clampedZoom(committedZoomScale * value)
                panOffset = clampedPan(panOffset, scale: zoomScale, containerSize: containerSize)
            }
            .onEnded { _ in
                committedZoomScale = zoomScale
                committedPanOffset = panOffset
            }
    }

    private func panGesture(containerSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let candidate = CGSize(
                    width: committedPanOffset.width + value.translation.width,
                    height: committedPanOffset.height + value.translation.height
                )
                panOffset = clampedPan(candidate, scale: zoomScale, containerSize: containerSize)
            }
            .onEnded { _ in
                committedPanOffset = panOffset
            }
    }

    private func clampedZoom(_ value: CGFloat) -> CGFloat {
        min(max(value, minZoom), maxZoom)
    }

    /// Keeps the zoomed image from panning past its own edge — the pannable
    /// range grows with how much extra size the zoom added.
    private func clampedPan(_ offset: CGSize, scale: CGFloat, containerSize: CGSize) -> CGSize {
        let maxX = containerSize.width * (scale - 1) / 2
        let maxY = containerSize.height * (scale - 1) / 2
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    private func resetZoom() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            zoomScale = 1
            committedZoomScale = 1
            panOffset = .zero
            committedPanOffset = .zero
        }
    }

    private func scrub(to x: CGFloat, width: CGFloat) {
        guard vm.radarFrames.count > 1, width > 0 else { return }
        let fraction = min(max(x / width, 0), 1)
        vm.radarFrameIndex = Int((fraction * Double(vm.radarFrames.count - 1)).rounded())
    }

    private func togglePlayback() {
        isPlaying.toggle()
        isPlaying ? startPlayback() : stopPlayback()
    }

    private func startPlayback() {
        playbackTask?.cancel()
        playbackTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 600_000_000)
                guard !Task.isCancelled, !vm.radarFrames.isEmpty else { break }
                vm.radarFrameIndex = (vm.radarFrameIndex + 1) % vm.radarFrames.count
            }
        }
    }

    private func stopPlayback() {
        isPlaying = false
        playbackTask?.cancel()
        playbackTask = nil
    }
}

private struct LoadingSkeletonPatch: View {
    var body: some View {
        ShimmerSkeleton(cornerRadius: 24)
            .padding(0)
    }
}

#Preview {
    RadarView(vm: WeatherViewModel())
}
