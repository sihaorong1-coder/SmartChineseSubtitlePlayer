import Foundation

/// 视频项数据模型
/// 用于记录用户播放过的视频信息
struct VideoItem: Identifiable, Codable, Equatable {
    /// 唯一标识符
    let id: UUID

    /// 视频文件本地 URL
    let url: URL

    /// 视频文件名称
    var title: String

    /// 视频文件大小（字节）
    var fileSize: Int64?

    /// 视频时长（秒）
    var duration: TimeInterval?

    /// 最后播放位置（秒）
    var lastPlaybackPosition: TimeInterval

    /// 最后播放日期
    var lastPlayedDate: Date

    /// 是否有可用字幕
    var hasSubtitles: Bool

    /// 字幕语言列表
    var subtitleLanguages: [String]

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        url: URL,
        title: String = "",
        fileSize: Int64? = nil,
        duration: TimeInterval? = nil,
        lastPlaybackPosition: TimeInterval = 0,
        lastPlayedDate: Date = Date(),
        hasSubtitles: Bool = false,
        subtitleLanguages: [String] = []
    ) {
        self.id = id
        self.url = url
        self.title = title.isEmpty ? url.lastPathComponent : title
        self.fileSize = fileSize
        self.duration = duration
        self.lastPlaybackPosition = lastPlaybackPosition
        self.lastPlayedDate = lastPlayedDate
        self.hasSubtitles = hasSubtitles
        self.subtitleLanguages = subtitleLanguages
    }

    /// 格式化文件大小
    var formattedFileSize: String {
        guard let size = fileSize else { return "未知大小" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    /// 格式化播放位置
    var formattedPlaybackPosition: String {
        let hours = Int(lastPlaybackPosition) / 3600
        let minutes = (Int(lastPlaybackPosition) % 3600) / 60
        let seconds = Int(lastPlaybackPosition) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
