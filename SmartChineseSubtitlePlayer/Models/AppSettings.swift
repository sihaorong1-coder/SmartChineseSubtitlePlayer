import Foundation
import SwiftUI

/// App 全局设置模型
/// 使用 UserDefaults 持久化存储，支持响应式更新
final class AppSettings: ObservableObject {
    // MARK: - Published Properties

    /// 字幕字体大小（默认 18pt）
    @Published var subtitleFontSize: CGFloat {
        didSet { save(key: .subtitleFontSize, value: subtitleFontSize) }
    }

    /// 字幕显示位置
    @Published var subtitlePosition: SubtitlePosition {
        didSet { save(key: .subtitlePosition, value: subtitlePosition.rawValue) }
    }

    /// 是否自动翻译外语字幕
    @Published var autoTranslateEnabled: Bool {
        didSet { save(key: .autoTranslateEnabled, value: autoTranslateEnabled) }
    }

    /// 是否优先使用本地字幕
    @Published var preferLocalSubtitles: Bool {
        didSet { save(key: .preferLocalSubtitles, value: preferLocalSubtitles) }
    }

    /// 是否启用语音识别生成字幕
    @Published var speechRecognitionEnabled: Bool {
        didSet { save(key: .speechRecognitionEnabled, value: speechRecognitionEnabled) }
    }

    /// 字幕时间偏移（秒），正数=延迟显示，负数=提前显示
    @Published var subtitleOffset: TimeInterval {
        didSet { save(key: .subtitleOffset, value: subtitleOffset) }
    }

    /// 是否显示字幕
    @Published var subtitlesEnabled: Bool {
        didSet { save(key: .subtitlesEnabled, value: subtitlesEnabled) }
    }

    // MARK: - Singleton

    static let shared = AppSettings()

    // MARK: - Private Init

    private init() {
        self.subtitleFontSize = Self.load(key: .subtitleFontSize, defaultValue: 18.0)
        self.subtitlePosition = SubtitlePosition(
                rawValue: Self.load(key: .subtitlePosition, defaultValue: SubtitlePosition.bottom.rawValue)
            ) ?? .bottom
        self.autoTranslateEnabled = Self.load(key: .autoTranslateEnabled, defaultValue: true)
        self.preferLocalSubtitles = Self.load(key: .preferLocalSubtitles, defaultValue: true)
        self.speechRecognitionEnabled = Self.load(key: .speechRecognitionEnabled, defaultValue: false)
        self.subtitleOffset = Self.load(key: .subtitleOffset, defaultValue: 0.0)
        self.subtitlesEnabled = Self.load(key: .subtitlesEnabled, defaultValue: true)
    }

    // MARK: - UserDefaults Helpers

    private enum StorageKey: String {
        case subtitleFontSize
        case subtitlePosition
        case autoTranslateEnabled
        case preferLocalSubtitles
        case speechRecognitionEnabled
        case subtitleOffset
        case subtitlesEnabled
    }

    private func save<T>(key: StorageKey, value: T) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    private static func load<T>(key: StorageKey, defaultValue: T) -> T {
        return UserDefaults.standard.object(forKey: key.rawValue) as? T ?? defaultValue
    }

    // MARK: - Reset

    /// 重置所有设置为默认值
    func resetToDefaults() {
        subtitleFontSize = 18.0
        subtitlePosition = .bottom
        autoTranslateEnabled = true
        preferLocalSubtitles = true
        speechRecognitionEnabled = false
        subtitleOffset = 0.0
        subtitlesEnabled = true
    }
}
