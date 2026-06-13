import Foundation

/// 字幕数据模型
/// 用于表示单条字幕的所有信息，包括时间轴、原文和译文
struct SubtitleItem: Identifiable, Codable, Equatable {
    /// 唯一标识符
    let id: UUID

    /// 字幕开始时间（秒）
    var startTime: TimeInterval

    /// 字幕结束时间（秒）
    var endTime: TimeInterval

    /// 原始字幕文本
    var originalText: String

    /// 翻译后的中文文本
    var translatedText: String?

    /// 字幕语言代码（如 "zh", "en", "ja", "ko"）
    var language: String

    /// 是否为机器翻译结果
    var isMachineTranslated: Bool

    /// 字幕来源类型
    var source: SubtitleSource

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        originalText: String,
        translatedText: String? = nil,
        language: String = "unknown",
        isMachineTranslated: Bool = false,
        source: SubtitleSource = .unknown
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.originalText = originalText
        self.translatedText = translatedText
        self.language = language
        self.isMachineTranslated = isMachineTranslated
        self.source = source
    }

    /// 获取当前应显示的文本（优先使用译文）
    var displayText: String {
        return translatedText ?? originalText
    }

    /// 字幕持续时间
    var duration: TimeInterval {
        return endTime - startTime
    }

    /// 是否已翻译
    var isTranslated: Bool {
        return translatedText != nil
    }

    /// 是否需要翻译（非中文）
    var needsTranslation: Bool {
        return language != "zh" && language != "zh-Hans" && language != "zh-Hant"
    }
}

// MARK: - Supporting Types

/// 字幕来源枚举
enum SubtitleSource: String, Codable, CaseIterable {
    /// 视频内嵌字幕轨道
    case embedded
    /// 外部字幕文件（如 .srt, .vtt）
    case externalFile
    /// 语音识别生成
    case speechRecognition
    /// 未知来源
    case unknown

    var displayName: String {
        switch self {
        case .embedded: return "内嵌字幕"
        case .externalFile: return "外部字幕文件"
        case .speechRecognition: return "语音识别"
        case .unknown: return "未知来源"
        }
    }
}

/// 字幕显示位置
enum SubtitlePosition: String, Codable, CaseIterable {
    case top
    case middle
    case bottom

    var displayName: String {
        switch self {
        case .top: return "顶部"
        case .middle: return "中部"
        case .bottom: return "底部"
        }
    }
}
