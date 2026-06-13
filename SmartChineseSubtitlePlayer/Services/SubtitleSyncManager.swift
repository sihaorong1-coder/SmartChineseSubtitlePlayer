import Foundation
import Combine
import AVFoundation

/// 字幕同步管理器
/// 负责将字幕与视频播放时间轴进行精确同步
/// 支持时间偏移调整、字幕切换等功能
final class SubtitleSyncManager: ObservableObject {

    // MARK: - Published Properties

    /// 当前应显示的字幕（可为 nil 表示无字幕）
    @Published var currentSubtitle: SubtitleItem?

    /// 所有已加载的字幕
    @Published private(set) var subtitles: [SubtitleItem] = []

    /// 字幕是否已加载
    @Published private(set) var isLoaded: Bool = false

    /// 字幕加载状态
    @Published private(set) var loadState: SubtitleLoadState = .idle

    // MARK: - Private Properties

    /// 字幕时间偏移（秒）
    private var timeOffset: TimeInterval = 0

    /// 字幕是否启用
    private var isEnabled: Bool = true

    /// 上一次已知的播放时间（用于去抖动）
    private var lastKnownTime: TimeInterval = -1

    /// 字幕查找索引（二分查找优化用）
    private var subtitleTimeStamps: [TimeInterval] = []

    /// Combine 订阅
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // 监听 AppSettings 的变化
        AppSettings.shared.$subtitleOffset
            .sink { [weak self] offset in
                self?.timeOffset = offset
            }
            .store(in: &cancellables)

        AppSettings.shared.$subtitlesEnabled
            .sink { [weak self] enabled in
                self?.isEnabled = enabled
                if !enabled {
                    self?.currentSubtitle = nil
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// 加载字幕
    /// - Parameter subtitles: 字幕数组
    func loadSubtitles(_ subtitles: [SubtitleItem]) {
        self.subtitles = subtitles.sorted { $0.startTime < $1.startTime }
        self.subtitleTimeStamps = self.subtitles.map { $0.startTime }
        self.isLoaded = !self.subtitles.isEmpty
        self.loadState = self.subtitles.isEmpty ? .empty : .loaded
        self.currentSubtitle = nil
    }

    /// 根据当前播放时间更新字幕
    /// - Parameter time: 当前播放时间（秒）
    func updatePlaybackTime(_ time: TimeInterval) {
        guard isEnabled, isLoaded, !subtitles.isEmpty else {
            if currentSubtitle != nil {
                currentSubtitle = nil
            }
            return
        }

        // 应用时间偏移
        let adjustedTime = time - timeOffset

        // 去抖动：避免过于频繁地更新同一字幕
        guard abs(adjustedTime - lastKnownTime) > 0.05 else { return }
        lastKnownTime = adjustedTime

        // 查找当前应显示的字幕
        let subtitle = findSubtitle(at: adjustedTime)

        if subtitle?.id != currentSubtitle?.id {
            currentSubtitle = subtitle
        }
    }

    /// 获取指定时间点的字幕
    /// - Parameter time: 时间（秒）
    /// - Returns: 字幕项（如果存在）
    func getSubtitle(at time: TimeInterval) -> SubtitleItem? {
        let adjustedTime = time - timeOffset
        return findSubtitle(at: adjustedTime)
    }

    /// 获取指定时间范围内的所有字幕
    /// - Parameter range: 时间范围
    /// - Returns: 字幕数组
    func getSubtitles(in range: ClosedRange<TimeInterval>) -> [SubtitleItem] {
        let adjustedRange = (range.lowerBound - timeOffset)...(range.upperBound - timeOffset)
        return subtitles.filter { subtitle in
            subtitle.startTime <= adjustedRange.upperBound && subtitle.endTime >= adjustedRange.lowerBound
        }
    }

    /// 设置时间偏移
    /// - Parameter offset: 偏移量（秒，正数为延迟，负数为提前）
    func setTimeOffset(_ offset: TimeInterval) {
        self.timeOffset = offset
        // 更新 AppSettings
        AppSettings.shared.subtitleOffset = offset
    }

    /// 调整时间偏移
    /// - Parameter delta: 偏移变化量
    func adjustTimeOffset(by delta: TimeInterval) {
        setTimeOffset(timeOffset + delta)
    }

    /// 获取当前时间偏移
    func getTimeOffset() -> TimeInterval {
        return timeOffset
    }

    /// 启用/禁用字幕
    func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
        AppSettings.shared.subtitlesEnabled = enabled
        if !enabled {
            currentSubtitle = nil
        }
    }

    /// 清除字幕
    func clearSubtitles() {
        subtitles = []
        subtitleTimeStamps = []
        isLoaded = false
        loadState = .idle
        currentSubtitle = nil
    }

    /// 更新字幕译文
    /// - Parameter translatedSubtitles: 翻译后的字幕数组
    func updateTranslations(_ translatedSubtitles: [SubtitleItem]) {
        var updatedSubtitles = subtitles
        for translated in translatedSubtitles {
            if let index = updatedSubtitles.firstIndex(where: { $0.id == translated.id }) {
                updatedSubtitles[index].translatedText = translated.translatedText
                updatedSubtitles[index].language = translated.language
                updatedSubtitles[index].isMachineTranslated = translated.isMachineTranslated
            }
        }
        self.subtitles = updatedSubtitles

        // 更新当前字幕
        if let current = currentSubtitle,
           let updated = translatedSubtitles.first(where: { $0.id == current.id }) {
            currentSubtitle = updated
        }
    }

    /// 字幕总数
    var subtitleCount: Int {
        return subtitles.count
    }

    /// 字幕总时长
    var totalDuration: TimeInterval {
        return subtitles.last?.endTime ?? 0
    }

    // MARK: - Private Methods

    /// 使用二分查找定位当前字幕
    /// - Parameter time: 调整后的播放时间
    /// - Returns: 匹配的字幕（如果存在）
    private func findSubtitle(at time: TimeInterval) -> SubtitleItem? {
        guard !subtitles.isEmpty else { return nil }

        // 使用二分查找找到起始时间最接近的字幕索引
        var left = 0
        var right = subtitles.count - 1
        var bestIndex: Int? = nil

        while left <= right {
            let mid = (left + right) / 2
            let subtitle = subtitles[mid]

            if time >= subtitle.startTime && time < subtitle.endTime {
                // 精确匹配
                return subtitle
            } else if time < subtitle.startTime {
                // 在当前字幕之前，记录这个索引
                bestIndex = mid
                right = mid - 1
            } else {
                left = mid + 1
            }
        }

        // 如果没有精确匹配，找到时间之后的第一条或之前的最后一条
        if let index = bestIndex, index > 0 {
            let previous = subtitles[index - 1]
            if time >= previous.startTime && time < previous.endTime {
                return previous
            }
        }

        return nil
    }
}

// MARK: - Supporting Types

/// 字幕加载状态
enum SubtitleLoadState: Equatable {
    case idle
    case loading(String)  // 加载中，附带状态描述
    case loaded
    case empty
    case error(String)    // 加载失败，附带错误信息

    var displayMessage: String {
        switch self {
        case .idle:
            return "等待加载"
        case .loading(let message):
            return message
        case .loaded:
            return "字幕已加载"
        case .empty:
            return "无字幕"
        case .error(let message):
            return message
        }
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
