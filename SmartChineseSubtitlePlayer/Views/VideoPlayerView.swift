import SwiftUI
import AVKit
import AVFoundation

/// 视频播放器视图
/// 核心视频播放页面，包含播放器、字幕叠加层和控制界面
struct VideoPlayerView: View {

    // MARK: - Properties

    let videoURL: URL

    @StateObject private var viewModel = VideoPlayerViewModel()
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var subtitleSyncManager: SubtitleSyncManager

    @State private var showControls = true
    @State private var controlsAutoHideTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    // MARK: - Initialization

    init(videoURL: URL) {
        self.videoURL = videoURL
        let vm = VideoPlayerViewModel()
        _viewModel = StateObject(wrappedValue: vm)
        _subtitleSyncManager = ObservedObject(wrappedValue: vm.subtitleSyncManager)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                // 背景
                Color.black.ignoresSafeArea()

                // 视频播放层
                videoPlayerLayer
                    .ignoresSafeArea()

                // 字幕叠加层
                subtitleOverlayLayer

                // 半透明渐变遮罩（上下两侧）
                if showControls {
                    controlGradients
                }

                // 加载指示器
                if viewModel.isLoadingVideo || viewModel.subtitleProcessingState.isLoading {
                    loadingOverlay
                }

                // 中央播放/暂停按钮
                if showControls {
                    centerPlayButton
                }

                // 控制界面
                if showControls {
                    VStack(spacing: 0) {
                        // 顶部控制栏
                        topControlBar

                        Spacer()

                        // 底部控制栏
                        bottomControlBar
                    }
                }

                // 字幕设置面板
                if viewModel.showControlPanel {
                    subtitleControlPanelOverlay
                }

                // 错误提示
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }
            }
            .onTapGesture { location in
                handleTapGesture(location: location)
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(!showControls || viewModel.isFullScreen)
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.loadVideo(from: videoURL)
            resetControlsAutoHide()
        }
        .onDisappear {
            viewModel.pause()
            controlsAutoHideTask?.cancel()
            videoURL.stopAccessingSecurityScopedResource()
        }
        .persistentSystemOverlays(.hidden)
    }

    // MARK: - Video Player Layer

    private var videoPlayerLayer: some View {
        Group {
            if let player = viewModel.player {
                VideoPlayerViewRepresentable(player: player)
                    .ignoresSafeArea()
            } else if viewModel.isLoadingVideo {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            } else {
                // 视频未加载
                VStack(spacing: 12) {
                    Image(systemName: "play.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))
                    Text("视频未加载")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
    }

    // MARK: - Subtitle Overlay

    private var subtitleOverlayLayer: some View {
        SubtitleOverlayView(
            subtitle: subtitleSyncManager.currentSubtitle,
            position: settings.subtitlePosition,
            fontSize: settings.subtitleFontSize,
            isVisible: settings.subtitlesEnabled
        )
        .allowsHitTesting(false)  // 不拦截触摸事件
    }

    // MARK: - Control Gradients

    private var controlGradients: some View {
        VStack {
            // 顶部渐变
            LinearGradient(
                colors: [.black.opacity(0.6), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
            .ignoresSafeArea(edges: .top)

            Spacer()

            // 底部渐变
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .ignoresSafeArea(edges: .bottom)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(viewModel.isLoadingVideo ? "正在加载视频..." : viewModel.subtitleProcessingState.displayMessage)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    // MARK: - Center Play Button

    private var centerPlayButton: some View {
        Group {
            if !viewModel.isPlaying && !viewModel.isLoadingVideo {
                Button(action: {
                    viewModel.play()
                    resetControlsAutoHide()
                }) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 72, height: 72)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Top Control Bar

    private var topControlBar: some View {
        HStack {
            // 返回按钮
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            }

            Spacer()

            // 视频标题
            VStack(spacing: 2) {
                Text(viewModel.videoTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)

                // 字幕状态指示
                subtitleStatusIndicator
            }

            Spacer()

            // 字幕设置按钮
            Button(action: {
                withAnimation(.spring(response: 0.35)) {
                    viewModel.showControlPanel.toggle()
                }
            }) {
                Image(systemName: "captions.bubble")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Subtitle Status Indicator

    private var subtitleStatusIndicator: some View {
        Group {
            switch viewModel.subtitleProcessingState {
            case .idle:
                EmptyView()
            case .loading(let message):
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(.white.opacity(0.8))
                    Text(message)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            case .ready:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("中文字幕")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            case .partialReady(let message):
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    Text(message)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            case .error(let message):
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                    Text(message)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Bottom Control Bar

    private var bottomControlBar: some View {
        VStack(spacing: 8) {
            // 进度条
            progressSlider

            // 控制按钮行
            HStack(spacing: 0) {
                // 当前时间
                Text(formatTime(viewModel.currentTime))
                    .font(.caption)
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .frame(width: 52, alignment: .leading)

                Spacer()

                // 快退 10 秒
                Button(action: {
                    viewModel.skipBackward(10)
                }) {
                    Image(systemName: "gobackward.10")
                        .font(.title3)
                        .foregroundColor(.white)
                }

                Spacer()

                // 播放/暂停
                Button(action: {
                    viewModel.togglePlayPause()
                    resetControlsAutoHide()
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                // 快进 10 秒
                Button(action: {
                    viewModel.skipForward(10)
                }) {
                    Image(systemName: "goforward.10")
                        .font(.title3)
                        .foregroundColor(.white)
                }

                Spacer()

                // 总时长
                Text(formatTime(viewModel.duration))
                    .font(.caption)
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }
            .padding(.horizontal, 12)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 20)
    }

    // MARK: - Progress Slider

    private var progressSlider: some View {
        VStack(spacing: 0) {
            Slider(
                value: Binding(
                    get: { viewModel.progress },
                    set: { newValue in
                        viewModel.seek(toProgress: newValue)
                    }
                ),
                in: 0...1
            ) { editing in
                if editing {
                    controlsAutoHideTask?.cancel()
                } else {
                    resetControlsAutoHide()
                }
            }
            .tint(.blue)
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Subtitle Control Panel Overlay

    private var subtitleControlPanelOverlay: some View {
        ZStack {
            // 背景遮罩
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.showControlPanel = false
                    }
                }

            // 控制面板
            VStack {
                Spacer()
                SubtitleControlPanel(
                    viewModel: viewModel,
                    settings: settings
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 20)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)

                Text(message)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(2)

                Spacer()

                Button {
                    viewModel.errorMessage = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.85))
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Gesture Handling

    private func handleTapGesture(location: CGPoint) {
        let screenHeight = UIScreen.main.bounds.height
        // 忽略底部 1/4 区域的点击（避免与底部控制按钮冲突）
        if location.y > screenHeight * 0.75 && showControls {
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            showControls.toggle()
        }

        if showControls {
            resetControlsAutoHide()
        } else {
            controlsAutoHideTask?.cancel()
        }
    }

    // MARK: - Auto Hide Controls

    private func resetControlsAutoHide() {
        controlsAutoHideTask?.cancel()
        controlsAutoHideTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)  // 4 秒
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if !viewModel.showControlPanel {
                        showControls = false
                    }
                }
            }
        }
    }

    // MARK: - Format Time

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - VideoPlayerViewRepresentable (UIViewRepresentable)

/// 将 AVPlayer 包装为 SwiftUI 视图
struct VideoPlayerViewRepresentable: UIViewControllerRepresentable {

    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false  // 使用自定义控件
        controller.videoGravity = .resizeAspect
        controller.allowsPictureInPicturePlayback = true

        // 设置音频会话
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session: \(error)")
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // 无需频繁更新
    }
}

// MARK: - Preview

#Preview {
    VideoPlayerView(videoURL: URL(string: "file:///sample.mp4")!)
}
