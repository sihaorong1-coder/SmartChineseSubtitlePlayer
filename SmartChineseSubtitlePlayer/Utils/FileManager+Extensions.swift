import Foundation

// MARK: - FileManager Video Utilities

extension FileManager {

    /// 获取 App 的文档目录
    var documentsDirectory: URL {
        return urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    /// 获取 App 的缓存目录
    var cachesDirectory: URL {
        return urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    /// 创建安全范围书签
    /// - Parameter url: 文件 URL
    /// - Returns: 书签数据
    func createSecurityScopedBookmark(for url: URL) throws -> Data {
        return try url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// 从书签解析 URL
    /// - Parameter bookmarkData: 书签数据
    /// - Returns: 文件 URL（如果可访问）
    func resolveSecurityScopedBookmark(_ bookmarkData: Data) throws -> URL {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return url
    }

    /// 检查文件是否为支持的视频格式
    /// - Parameter url: 文件 URL
    /// - Returns: 是否支持
    func isSupportedVideoFormat(_ url: URL) -> Bool {
        let supportedExtensions = ["mp4", "mov", "m4v", "avi", "mkv", "flv", "wmv", "webm"]
        let ext = url.pathExtension.lowercased()
        return supportedExtensions.contains(ext)
    }

    /// 获取文件大小描述
    /// - Parameter url: 文件 URL
    /// - Returns: 格式化的大小字符串
    func formattedFileSize(at url: URL) -> String {
        guard let attributes = try? attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int64 else {
            return "未知大小"
        }
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// 清理临时文件
    func clearTemporaryFiles() {
        let tempDir = temporaryDirectory
        guard let contents = try? contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return }

        for url in contents {
            try? removeItem(at: url)
        }
    }

    /// 计算目录大小
    /// - Parameter directory: 目录 URL
    /// - Returns: 字节数
    func sizeOfDirectory(at directory: URL) -> Int64 {
        var totalSize: Int64 = 0
        guard let enumerator = enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return 0 }

        for case let url as URL in enumerator {
            if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        return totalSize
    }
}

// MARK: - URL Video Utilities

extension URL {

    /// 是否为视频文件
    var isVideoFile: Bool {
        let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv", "flv", "wmv", "webm"]
        return videoExtensions.contains(pathExtension.lowercased())
    }

    /// 是否为字幕文件
    var isSubtitleFile: Bool {
        let subtitleExtensions = ["srt", "vtt", "ass", "ssa", "sub"]
        return subtitleExtensions.contains(pathExtension.lowercased())
    }

    /// 文件名（不含扩展名）
    var fileNameWithoutExtension: String {
        return deletingPathExtension().lastPathComponent
    }
}
