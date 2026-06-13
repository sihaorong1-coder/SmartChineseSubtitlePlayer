import Foundation
import SwiftUI
import Combine

/// 设置页面 ViewModel
/// 管理 App 所有设置的读取和修改
@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    /// 字幕字体大小 (12-36)
    @Published var subtitleFontSize: CGFloat {
        didSet { settings.subtitleFontSize = subtitleFontSize }
    }

    /// 字幕显示位置
    @Published var subtitlePosition: SubtitlePosition {
        didSet { settings.subtitlePosition = subtitlePosition }
    }

    /// 是否自动翻译外语字幕
    @Published var autoTranslateEnabled: Bool {
        didSet { settings.autoTranslateEnabled = autoTranslateEnabled }
    }

    /// 是否优先使用本地字幕
    @Published var preferLocalSubtitles: Bool {
        didSet { settings.preferLocalSubtitles = preferLocalSubtitles }
    }

    /// 是否启用语音识别生成字幕
    @Published var speechRecognitionEnabled: Bool {
        didSet { settings.speechRecognitionEnabled = speechRecognitionEnabled }
    }

    /// 字幕时间偏移
    @Published var subtitleOffset: TimeInterval {
        didSet { settings.subtitleOffset = subtitleOffset }
    }

    /// 是否显示字幕
    @Published var subtitlesEnabled: Bool {
        didSet { settings.subtitlesEnabled = subtitlesEnabled }
    }

    /// App 版本号
    @Published var appVersion: String = ""

    /// Build 号
    @Published var buildNumber: String = ""

    /// 缓存大小描述
    @Published var cacheSizeDescription: String = "计算中..."

    // MARK: - Private Properties

    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        self.subtitleFontSize = settings.subtitleFontSize
        self.subtitlePosition = settings.subtitlePosition
        self.autoTranslateEnabled = settings.autoTranslateEnabled
        self.preferLocalSubtitles = settings.preferLocalSubtitles
        self.speechRecognitionEnabled = settings.speechRecognitionEnabled
        self.subtitleOffset = settings.subtitleOffset
        self.subtitlesEnabled = settings.subtitlesEnabled

        loadAppInfo()
        calculateCacheSize()
    }

    // MARK: - Public Methods

    /// 重置所有设置
    func resetAllSettings() {
        settings.resetToDefaults()

        // 同步本地属性
        subtitleFontSize = settings.subtitleFontSize
        subtitlePosition = settings.subtitlePosition
        autoTranslateEnabled = settings.autoTranslateEnabled
        preferLocalSubtitles = settings.preferLocalSubtitles
        speechRecognitionEnabled = settings.speechRecognitionEnabled
        subtitleOffset = settings.subtitleOffset
        subtitlesEnabled = settings.subtitlesEnabled
    }

    /// 清除缓存
    func clearCache() {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: tempDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            for url in contents {
                try? fileManager.removeItem(at: url)
            }
            calculateCacheSize()
        } catch {
            // 忽略错误
        }
    }

    /// 偏移预设值
    func setOffsetPreset(_ preset: SubtitleOffsetPreset) {
        let offset = preset.timeInterval
        subtitleOffset = offset
        settings.subtitleOffset = offset
    }

    // MARK: - Private Methods

    private func loadAppInfo() {
        let bundle = Bundle.main
        appVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        buildNumber = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func calculateCacheSize() {
        // 异步计算缓存大小
        Task {
            let size = await computeCacheSize()
            await MainActor.run {
                self.cacheSizeDescription = size
            }
        }
    }

    private func computeCacheSize() async -> String {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory

        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: tempDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return "未知"
        }

        for case let url as URL in enumerator {
            if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }

        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

// MARK: - Offset Presets

/// 字幕时间偏移预设
enum SubtitleOffsetPreset: String, CaseIterable, Identifiable {
    case early2s = "提前 2 秒"
    case early1s = "提前 1 秒"
    case early05s = "提前 0.5 秒"
    case normal = "无偏移"
    case late05s = "延后 0.5 秒"
    case late1s = "延后 1 秒"
    case late2s = "延后 2 秒"

    var id: String { rawValue }

    var timeInterval: TimeInterval {
        switch self {
        case .early2s: return -2.0
        case .early1s: return -1.0
        case .early05s: return -0.5
        case .normal: return 0.0
        case .late05s: return 0.5
        case .late1s: return 1.0
        case .late2s: return 2.0
        }
    }
}
