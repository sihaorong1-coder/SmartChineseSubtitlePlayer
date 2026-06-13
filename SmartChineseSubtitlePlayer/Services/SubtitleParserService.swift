import Foundation
import AVFoundation

/// 字幕解析服务
/// 负责从视频文件中提取内嵌字幕轨道，以及解析外部字幕文件（SRT、VTT 格式）
final class SubtitleParserService {

    // MARK: - Error Types

    enum SubtitleParserError: LocalizedError {
        case noSubtitleTracks
        case unsupportedFormat(String)
        case parseError(String)
        case fileNotFound
        case invalidFormat

        var errorDescription: String? {
            switch self {
            case .noSubtitleTracks:
                return "视频中没有找到字幕轨道"
            case .unsupportedFormat(let format):
                return "不支持的字幕格式: \(format)"
            case .parseError(let detail):
                return "字幕解析失败: \(detail)"
            case .fileNotFound:
                return "字幕文件未找到"
            case .invalidFormat:
                return "字幕文件格式无效"
            }
        }
    }

    // MARK: - Public Methods

    /// 从 AVAsset 中提取内嵌字幕
    /// - Parameter asset: 视频资源
    /// - Returns: 字幕数组
    func extractEmbeddedSubtitles(from asset: AVAsset) async throws -> [SubtitleItem] {
        // 获取所有媒体特征
        let mediaCharacteristics: [AVMediaCharacteristic] = [
            .legible,
            .containsAlphaChannel
        ]

        // 首先尝试获取中文字幕轨道
        var subtitleTracks: [AVMediaSelectionOption] = []

        if let legibleGroup = asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            // 优先查找中文字幕
            let chineseOptions = legibleGroup.options.filter { option in
                let displayName = option.displayName.lowercased()
                let locale = option.locale
                return displayName.contains("中文") ||
                       displayName.contains("chinese") ||
                       displayName.contains("zh") ||
                       displayName.contains("chs") ||
                       displayName.contains("cht") ||
                       locale?.identifier.hasPrefix("zh") == true
            }

            if !chineseOptions.isEmpty {
                subtitleTracks = chineseOptions
            } else {
                // 如果没有中文，获取所有字幕轨道
                subtitleTracks = legibleGroup.options
            }
        }

        guard !subtitleTracks.isEmpty else {
            throw SubtitleParserError.noSubtitleTracks
        }

        // 解析字幕内容
        var allSubtitles: [SubtitleItem] = []

        for option in subtitleTracks {
            let subtitles = try await parseAVMediaSelectionOption(option, from: asset)
            allSubtitles.append(contentsOf: subtitles)
        }

        // 按开始时间排序并去重
        let sortedSubtitles = allSubtitles.sorted { $0.startTime < $1.startTime }
        let deduplicated = removeDuplicates(sortedSubtitles)

        return deduplicated
    }

    /// 解析外部 SRT 字幕文件
    /// - Parameter fileURL: SRT 文件 URL
    /// - Returns: 字幕数组
    func parseSRTFile(at fileURL: URL) throws -> [SubtitleItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw SubtitleParserError.fileNotFound
        }

        let content: String
        do {
            // 尝试常见编码
            content = try readFileWithEncoding(fileURL)
        } catch {
            throw SubtitleParserError.parseError("无法读取文件: \(error.localizedDescription)")
        }

        return try parseSRTContent(content)
    }

    /// 解析外部 VTT 字幕文件
    /// - Parameter fileURL: VTT 文件 URL
    /// - Returns: 字幕数组
    func parseVTTFile(at fileURL: URL) throws -> [SubtitleItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw SubtitleParserError.fileNotFound
        }

        let content: String
        do {
            content = try readFileWithEncoding(fileURL)
        } catch {
            throw SubtitleParserError.parseError("无法读取文件: \(error.localizedDescription)")
        }

        return try parseVTTContent(content)
    }

    /// 自动检测并解析字幕文件（根据扩展名）
    /// - Parameter fileURL: 字幕文件 URL
    /// - Returns: 字幕数组
    func autoParseSubtitleFile(at fileURL: URL) throws -> [SubtitleItem] {
        let ext = fileURL.pathExtension.lowercased()
        switch ext {
        case "srt":
            return try parseSRTFile(at: fileURL)
        case "vtt", "webvtt":
            return try parseVTTFile(at: fileURL)
        default:
            // 尝试两种格式
            do {
                return try parseSRTFile(at: fileURL)
            } catch {
                return try parseVTTFile(at: fileURL)
            }
        }
    }

    // MARK: - Private Methods

    /// 解析 AVMediaSelectionOption 获取字幕内容
    private func parseAVMediaSelectionOption(
        _ option: AVMediaSelectionOption,
        from asset: AVAsset
    ) async throws -> [SubtitleItem] {
        var subtitles: [SubtitleItem] = []

        // 确定语言
        let language = option.locale?.languageCode ?? "unknown"

        // TODO: 对于内嵌字幕，iOS 的原生提取能力有限
        // 当前使用 AVAssetReader 尝试读取字幕样本
        // 生产环境中建议使用 AVPlayerItem 的 legibleOutput 实时获取

        // 创建字幕输出
        // 注意：详细的字幕数据提取需要使用 AVAssetReader 配合字幕轨道的格式描述
        // 这里提供一个基本框架，实际字幕文本提取取决于视频的编码格式

        // 获取字幕轨道
        guard let subtitleTrack = try? await asset.loadTracks(withMediaCharacteristic: .legible).first else {
            return subtitles
        }

        // 使用 AVAssetReader 读取字幕数据
        guard let reader = try? AVAssetReader(asset: asset) else {
            return subtitles
        }

        let output = AVAssetReaderTrackOutput(track: subtitleTrack, outputSettings: nil)
        reader.add(output)
        reader.startReading()

        while let sampleBuffer = output.copyNextSampleBuffer() {
            if let subtitleItem = parseSubtitleSampleBuffer(sampleBuffer, language: language) {
                subtitles.append(subtitleItem)
            }
        }

        reader.cancelReading()

        return subtitles
    }

    /// 解析字幕 SampleBuffer
    private func parseSubtitleSampleBuffer(_ sampleBuffer: CMSampleBuffer, language: String) -> SubtitleItem? {
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetDuration(sampleBuffer)

        let startTime = CMTimeGetSeconds(presentationTime)
        let endTime = startTime + CMTimeGetSeconds(duration)

        // 尝试从 sampleBuffer 中获取文本
        // 字幕文本可能是 CEA-608/708、WebVTT 等格式
        // 这里尝试获取格式描述中的文本
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return nil
        }

        // 对于基本文本字幕，尝试提取
        var text: String? = nil

        // 检查是否是 WebVTT 或其他文本格式
        let mediaType = CMFormatDescriptionGetMediaType(formatDescription)
        if mediaType == kCMMediaType_Subtitle || mediaType == kCMMediaType_Text {
            // 尝试以不同方式获取字幕文本
            // 这里需要根据具体的字幕格式进行解析
            if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                text = readTextFromBlockBuffer(blockBuffer)
            }
        }

        guard let subtitleText = text, !subtitleText.isEmpty else {
            return nil
        }

        return SubtitleItem(
            startTime: startTime,
            endTime: endTime,
            originalText: subtitleText,
            language: language,
            source: .embedded
        )
    }

    /// 从 CMBlockBuffer 读取文本
    private func readTextFromBlockBuffer(_ blockBuffer: CMBlockBuffer) -> String? {
        var totalLength = 0
        guard CMBlockBufferGetDataLength(blockBuffer) == noErr else {
            return nil
        }
        // TODO: 实现完整的 CMBlockBuffer 文本提取逻辑
        // 需要根据不同的字幕编码格式解析
        return nil
    }

    /// 解析 SRT 内容
    private func parseSRTContent(_ content: String) throws -> [SubtitleItem] {
        var subtitles: [SubtitleItem] = []

        // 标准化换行
        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
                                 .replacingOccurrences(of: "\r", with: "\n")
        // 按双换行分割
        let blocks = normalized.components(separatedBy: "\n\n")

        for block in blocks {
            let lines = block.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard lines.count >= 3 else { continue }

            // 第一行是序号（跳过）
            // 第二行是时间轴
            let timeLine = lines[1]
            let textLines = Array(lines.dropFirst(2))

            guard let (startTime, endTime) = parseSRTTimeLine(timeLine) else {
                continue
            }

            let text = textLines.joined(separator: "\n")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { continue }

            let subtitle = SubtitleItem(
                startTime: startTime,
                endTime: endTime,
                originalText: text,
                source: .externalFile
            )
            subtitles.append(subtitle)
        }

        guard !subtitles.isEmpty else {
            throw SubtitleParserError.parseError("未能从SRT内容中解析出有效字幕")
        }

        return subtitles.sorted { $0.startTime < $1.startTime }
    }

    /// 解析 VTT 内容
    private func parseVTTContent(_ content: String) throws -> [SubtitleItem] {
        var subtitles: [SubtitleItem] = []

        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
                                 .replacingOccurrences(of: "\r", with: "\n")

        // 移除 WEBVTT 头部
        var lines = normalized.components(separatedBy: "\n")
        if let firstLine = lines.first, firstLine.uppercased().hasPrefix("WEBVTT") {
            lines = Array(lines.dropFirst())
        }

        // 移除元数据（NOTE, STYLE 等）
        lines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("NOTE") && !trimmed.hasPrefix("STYLE") && !trimmed.hasPrefix("REGION")
        }

        var currentStart: TimeInterval?
        var currentEnd: TimeInterval?
        var currentText: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                if let start = currentStart, let end = currentEnd, !currentText.isEmpty {
                    let text = currentText.joined(separator: "\n")
                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if !text.isEmpty {
                        let subtitle = SubtitleItem(
                            startTime: start,
                            endTime: end,
                            originalText: text,
                            source: .externalFile
                        )
                        subtitles.append(subtitle)
                    }
                }
                currentStart = nil
                currentEnd = nil
                currentText = []
                continue
            }

            // 尝试解析时间轴
            if let (start, end) = parseVTTTimeLine(trimmed) {
                currentStart = start
                currentEnd = end
            } else if currentStart != nil {
                currentText.append(trimmed)
            }
        }

        // 处理最后一条
        if let start = currentStart, let end = currentEnd, !currentText.isEmpty {
            let text = currentText.joined(separator: "\n")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                let subtitle = SubtitleItem(
                    startTime: start,
                    endTime: end,
                    originalText: text,
                    source: .externalFile
                )
                subtitles.append(subtitle)
            }
        }

        guard !subtitles.isEmpty else {
            throw SubtitleParserError.parseError("未能从VTT内容中解析出有效字幕")
        }

        return subtitles.sorted { $0.startTime < $1.startTime }
    }

    /// 解析 SRT 时间轴 "00:01:23,456 --> 00:01:25,789"
    private func parseSRTTimeLine(_ line: String) -> (TimeInterval, TimeInterval)? {
        let components = line.components(separatedBy: "-->")
        guard components.count == 2 else { return nil }

        guard let start = parseSRTTime(components[0].trimmingCharacters(in: .whitespaces)),
              let end = parseSRTTime(components[1].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }

        return (start, end)
    }

    /// 解析 SRT 时间 "00:01:23,456"
    private func parseSRTTime(_ timeString: String) -> TimeInterval? {
        let cleaned = timeString.replacingOccurrences(of: ",", with: ".")
        let parts = cleaned.components(separatedBy: ":")
        guard parts.count == 3,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(parts[2]) else {
            return nil
        }
        return hours * 3600 + minutes * 60 + seconds
    }

    /// 解析 VTT 时间轴 "00:01:23.456 --> 00:01:25.789"
    private func parseVTTTimeLine(_ line: String) -> (TimeInterval, TimeInterval)? {
        let components = line.components(separatedBy: "-->")
        guard components.count == 2 else { return nil }

        guard let start = parseVTTTime(components[0].trimmingCharacters(in: .whitespaces)),
              let end = parseVTTTime(components[1].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }

        return (start, end)
    }

    /// 解析 VTT 时间 "00:01:23.456"
    private func parseVTTTime(_ timeString: String) -> TimeInterval? {
        // VTT 时间可能包含小时也可能不包含
        let cleaned = timeString.trimmingCharacters(in: .whitespaces)
        let parts = cleaned.components(separatedBy: ":")
        switch parts.count {
        case 3:
            // HH:MM:SS.mmm
            guard let hours = Double(parts[0]),
                  let minutes = Double(parts[1]),
                  let seconds = Double(parts[2]) else {
                return nil
            }
            return hours * 3600 + minutes * 60 + seconds
        case 2:
            // MM:SS.mmm
            guard let minutes = Double(parts[0]),
                  let seconds = Double(parts[1]) else {
                return nil
            }
            return minutes * 60 + seconds
        default:
            return nil
        }
    }

    /// 以适当编码读取文件
    private func readFileWithEncoding(_ fileURL: URL) throws -> String {
        // 尝试 UTF-8
        if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
            return content
        }
        // 尝试 UTF-16
        if let content = try? String(contentsOf: fileURL, encoding: .utf16) {
            return content
        }
        // 尝试 GBK（中文常见编码）
        let gbkEncoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        if let content = try? String(contentsOf: fileURL, encoding: gbkEncoding) {
            return content
        }
        throw SubtitleParserError.parseError("无法识别文件编码，请使用 UTF-8 编码的字幕文件")
    }

    /// 去除重复字幕
    private func removeDuplicates(_ subtitles: [SubtitleItem]) -> [SubtitleItem] {
        var seen = Set<UUID>()
        var result: [SubtitleItem] = []
        for subtitle in subtitles {
            let key = subtitle.id
            if !seen.contains(key) {
                seen.insert(key)
                result.append(subtitle)
            }
        }
        return result
    }
}
