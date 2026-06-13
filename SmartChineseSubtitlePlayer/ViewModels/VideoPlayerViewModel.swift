import Foundation
import AVFoundation
import Combine
import SwiftUI

/// 视频播放器 ViewModel
/// 管理视频播放状态、字幕加载与显示的全部逻辑
@MainActor
final class VideoPlayerViewModel: ObservableObject {

    // MARK: - Published Properties

    /// AVPlayer 实例
    @Published var player: AVPlayer?

    /// 视频资源
    @Published private(set) var asset: AVAsset?

    /// 播放状态
    @Published var isPlaying: Bool = false

    /// 当前播放时间（秒）
    @Published var currentTime: TimeInterval = 0

    /// 视频总时长（秒）
    @Published var duration: TimeInterval = 0

    /// 播放进度 (0.0 ~ 1.0)
    @Published var progress: Double = 0

    /// 是否正在加载视频
    @Published var isLoadingVideo: Bool = false

    /// 视频标题
    @Published var videoTitle: String = ""

    /// 是否全屏
    @Published var isFullScreen: Bool = false

    /// 字幕处理状态
    @Published var subtitleProcessingState: SubtitleProcessingState = .idle

    /// 是否显示字幕控制面板
    @Published var showControlPanel: Bool = false

    /// 是否正在 seeking
    @Published var isSeeking: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Services

    let subtitleSyncManager = SubtitleSyncManager()
    private let subtitleParser = SubtitleParserService()
    private let translationService = TranslationService.shared
    private let speechRecognitionService = SpeechRecognitionService.shared
    private let languageDetectionService = LanguageDetectionService.shared

    // MARK: - Private Properties

    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var playerItemObservation: NSKeyValueObservation?

    // MARK: - Settings

    private var settings: AppSettings { AppSettings.shared }

    // MARK: - Initialization

    init() {
        setupSubtitleSyncBinding()
    }

    deinit {
        removeTimeObserver()
        playerItemObservation?.invalidate()
    }

    // MARK: - Setup

    private func setupSubtitleSyncBinding() {
        // 订阅字幕同步管理器的当前字幕
        subtitleSyncManager.$currentSubtitle
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Video Loading

    /// 加载视频文件
    /// - Parameter url: 视频文件 URL
    func loadVideo(from url: URL) {
        // 重置状态
        resetState()
        isLoadingVideo = true
        errorMessage = nil

        // 开始访问安全范围资源
        let didStartAccessing = url.startAccessingSecurityScopedResource()

        videoTitle = url.lastPathComponent

        let asset = AVAsset(url: url)
        self.asset = asset

        Task {
            do {
                // 加载视频属性
                let durationValue = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(durationValue)

                guard durationSeconds.isFinite, durationSeconds > 0 else {
                    throw VideoPlayerError.invalidVideo
                }

                self.duration = durationSeconds

                // 创建播放项
                let playerItem = AVPlayerItem(asset: asset)
                let newPlayer = AVPlayer(playerItem: playerItem)
                self.player = newPlayer

                // 添加时间观察器
                addTimeObserver()

                // 观察播放状态
                observePlayerState()

                // 视频加载完成
                self.isLoadingVideo = false

                // 自动开始字幕处理
                await processSubtitles(for: asset)

                // 如果启用了自动播放，自动开始
                // newPlayer.play()

            } catch {
                self.isLoadingVideo = false
                self.errorMessage = "视频加载失败: \(error.localizedDescription)"
            }

            // 停止安全范围资源访问（在适当的时候）
            if didStartAccessing {
                // url.stopAccessingSecurityScopedResource()
                // 注意：这里延迟释放访问权限，因为 AVPlayer 需要持续访问
                // 实际应在 View 的 onDisappear 中释放
            }
        }
    }

    /// 通过安全范围书签加载视频
    /// - Parameter bookmarkData: 安全范围书签数据
    func loadVideoFromBookmark(_ bookmarkData: Data) {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withoutUI,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            loadVideo(from: url)
        } catch {
            self.errorMessage = "无法访问视频文件: \(error.localizedDescription)"
        }
    }

    // MARK: - Playback Control

    /// 播放/暂停切换
    func togglePlayPause() {
        guard let player = player else { return }
        if player.rate == 0 {
            player.play()
            isPlaying = true
        } else {
            player.pause()
            isPlaying = false
        }
    }

    /// 播放
    func play() {
        player?.play()
        isPlaying = true
    }

    /// 暂停
    func pause() {
        player?.pause()
        isPlaying = false
    }

    /// 跳转到指定时间
    /// - Parameter time: 目标时间（秒）
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        isSeeking = true
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.isSeeking = false
        }
    }

    /// 跳转到指定进度
    /// - Parameter progress: 进度 (0.0 ~ 1.0)
    func seek(toProgress progress: Double) {
        let clampedProgress = max(0, min(1, progress))
        let targetTime = duration * clampedProgress
        seek(to: targetTime)
    }

    /// 快进
    func skipForward(_ seconds: TimeInterval = 10) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
    }

    /// 快退
    func skipBackward(_ seconds: TimeInterval = 10) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }

    /// 切换全屏
    func toggleFullScreen() {
        isFullScreen.toggle()
    }

    // MARK: - Subtitle Processing

    /// 处理字幕的主流程
    private func processSubtitles(for asset: AVAsset) async {
        subtitleProcessingState = .loading("正在检测字幕...")

        do {
            var loadedSubtitles: [SubtitleItem] = []

            // Step 1: 检查视频内嵌字幕
            if settings.preferLocalSubtitles {
                subtitleProcessingState = .loading("正在读取内嵌字幕...")

                if let embeddedSubtitles = try? await subtitleParser.extractEmbeddedSubtitles(from: asset),
                   !embeddedSubtitles.isEmpty {
                    loadedSubtitles = embeddedSubtitles
                }
            }

            // Step 2: 如果没有内嵌字幕，尝试语音识别
            if loadedSubtitles.isEmpty {
                // 对于通过文件 URL 加载的资产，尝试提取音频进行语音识别
                if settings.speechRecognitionEnabled {
                    subtitleProcessingState = .loading("正在进行语音识别...")
                    subtitleProcessingState = .loading("正在提取音频并识别语音，这可能需要几分钟...")

                    // 获取视频的 URL
                    if let urlAsset = asset as? AVURLAsset {
                        do {
                            loadedSubtitles = try await speechRecognitionService.recognizeSpeech(from: urlAsset.url)
                            subtitleProcessingState = .loading("语音识别完成，正在处理...")
                        } catch {
                            subtitleProcessingState = .error("语音识别失败，请检查网络或重新选择视频。错误: \(error.localizedDescription)")
                            return
                        }
                    }
                }

                // 如果仍然没有字幕
                if loadedSubtitles.isEmpty {
                    if settings.speechRecognitionEnabled {
                        subtitleProcessingState = .error("字幕生成失败：未能从视频中提取到任何字幕内容")
                    } else {
                        subtitleProcessingState = .error("此视频没有内嵌字幕。您可以在设置中开启"语音识别生成字幕"功能")
                    }
                    return
                }
            }

            // Step 3: 检测语言
            subtitleProcessingState = .loading("正在检测字幕语言...")
            let allText = loadedSubtitles.map { $0.originalText }.joined(separator: " ")
            let detectedLanguage = languageDetectionService.detectLanguage(of: allText)

            // 更新字幕语言
            loadedSubtitles = loadedSubtitles.map { subtitle in
                var updated = subtitle
                updated.language = detectedLanguage
                return updated
            }

            // Step 4: 如果不是中文，进行翻译
            if detectedLanguage.hasPrefix("zh") {
                subtitleProcessingState = .loading("中文字幕已就绪")
                subtitleSyncManager.loadSubtitles(loadedSubtitles)
                subtitleProcessingState = .ready
            } else if settings.autoTranslateEnabled {
                subtitleProcessingState = .loading("正在翻译字幕为中文...")

                do {
                    let translatedSubtitles = try await translationService.translateSubtitles(
                        loadedSubtitles,
                        from: detectedLanguage
                    )
                    subtitleSyncManager.loadSubtitles(translatedSubtitles)
                    subtitleProcessingState = .ready
                } catch {
                    // 翻译失败，仍然显示原始字幕
                    subtitleSyncManager.loadSubtitles(loadedSubtitles)
                    subtitleProcessingState = .partialReady("翻译失败，显示原始字幕。错误: \(error.localizedDescription)")
                }
            } else {
                // 不自动翻译，直接显示原始字幕
                subtitleSyncManager.loadSubtitles(loadedSubtitles)
                subtitleProcessingState = .ready
            }

        } catch {
            subtitleProcessingState = .error("字幕处理失败: \(error.localizedDescription)")
        }
    }

    /// 重新加载字幕（用户手动触发）
    func reloadSubtitles() async {
        guard let asset = asset else { return }
        subtitleSyncManager.clearSubtitles()
        await processSubtitles(for: asset)
    }

    // MARK: - Subtitle Display Control

    /// 切换字幕开/关
    func toggleSubtitles() {
        let newState = !settings.subtitlesEnabled
        subtitleSyncManager.setEnabled(newState)
    }

    /// 调整字幕时间偏移
    func adjustSubtitleOffset(by delta: TimeInterval) {
        subtitleSyncManager.adjustTimeOffset(by: delta)
    }

    /// 设置字幕位置
    func setSubtitlePosition(_ position: SubtitlePosition) {
        settings.subtitlePosition = position
    }

    /// 设置字幕大小
    func setSubtitleFontSize(_ size: CGFloat) {
        settings.subtitleFontSize = max(12, min(36, size))
    }

    /// 重置字幕偏移
    func resetSubtitleOffset() {
        subtitleSyncManager.setTimeOffset(0)
    }

    // MARK: - Private Methods

    private func addTimeObserver() {
        guard let player = player else { return }

        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, !self.isSeeking else { return }

            let seconds = CMTimeGetSeconds(time)
            self.currentTime = seconds
            self.progress = self.duration > 0 ? seconds / self.duration : 0

            // 同步字幕
            self.subtitleSyncManager.updatePlaybackTime(seconds)
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    private func observePlayerState() {
        // 观察播放完成
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in
                self?.isPlaying = false
                self?.progress = 1.0
            }
            .store(in: &cancellables)

        // 观察播放失败
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime)
            .sink { [weak self] notification in
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    self?.errorMessage = "播放失败: \(error.localizedDescription)"
                }
                self?.isPlaying = false
            }
            .store(in: &cancellables)

        // 观察播放速率
        player?.publisher(for: \.rate)
            .sink { [weak self] rate in
                self?.isPlaying = rate != 0
            }
            .store(in: &cancellables)
    }

    private func resetState() {
        removeTimeObserver()
        player?.pause()
        player = nil
        asset = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        progress = 0
        subtitleSyncManager.clearSubtitles()
        subtitleProcessingState = .idle
        errorMessage = nil
        cancellables.removeAll()
        setupSubtitleSyncBinding()
    }
}

// MARK: - Supporting Types

/// 字幕处理状态
enum SubtitleProcessingState: Equatable {
    case idle
    case loading(String)
    case ready
    case partialReady(String)
    case error(String)

    var displayMessage: String {
        switch self {
        case .idle:
            return ""
        case .loading(let message):
            return message
        case .ready:
            return "中文字幕已就绪"
        case .partialReady(let message):
            return message
        case .error(let message):
            return message
        }
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

/// 视频播放器错误
enum VideoPlayerError: LocalizedError {
    case invalidVideo
    case loadFailed(String)
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .invalidVideo:
            return "无效的视频文件"
        case .loadFailed(let detail):
            return "视频加载失败: \(detail)"
        case .unsupportedFormat:
            return "不支持的视频格式"
        }
    }
}
