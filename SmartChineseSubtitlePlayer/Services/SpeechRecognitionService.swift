import Foundation
import Speech
import AVFoundation

/// 语音识别服务协议
protocol SpeechRecognitionServiceProtocol {
    /// 从视频文件中提取音频并进行语音识别
    /// - Parameter videoURL: 视频文件 URL
    /// - Returns: 识别出的字幕数组
    func recognizeSpeech(from videoURL: URL) async throws -> [SubtitleItem]
}

/// 语音识别服务
///
/// ## 当前实现
/// 使用 Apple Speech Framework 进行本地语音识别。
/// 支持在设备端离线识别（需要下载语言包）。
///
/// ## 限制与 TODO
///
/// ### iOS 原生 Speech Framework 限制：
/// 1. 不支持直接从视频中提取音频 — 需要先使用 AVAssetReader 分离音轨
/// 2. 实时识别精度有限，特别是嘈杂环境
/// 3. 一次最多识别 1 分钟的音频片段
/// 4. 部分语言需要网络连接
/// 5. 时间戳精度有限（Apple 不保证精确到帧级别）
///
/// ### TODO: 云端语音识别 API 方案
///
/// #### 方案 A：Apple Speech Framework（当前）
/// - 优点：免费、隐私安全、支持离线
/// - 缺点：精度一般、时间戳不精确
///
/// #### 方案 B：OpenAI Whisper API
/// ```swift
/// // POST https://api.openai.com/v1/audio/transcriptions
/// // 支持多语言，返回带时间戳的文本
/// // 成本：$0.006/分钟
/// ```
///
/// #### 方案 C：Google Cloud Speech-to-Text API
/// ```swift
/// // 支持 120+ 语言
/// // 提供词级别时间戳
/// // 成本：$0.006/15秒（标准模型）
/// ```
///
/// #### 方案 D：Azure Speech Services
/// ```swift
/// // 支持实时和批量识别
/// // 提供详细的单词级时间戳
/// ```
///
/// #### 方案 E：阿里云语音识别
/// ```swift
/// // 支持中文识别效果优秀
/// // 提供实时和离线识别
/// // https://help.aliyun.com/product/30413.html
/// ```
final class SpeechRecognitionService: SpeechRecognitionServiceProtocol {

    // MARK: - Singleton

    static let shared = SpeechRecognitionService()

    private init() {}

    // MARK: - Properties

    /// 识别进度回调
    var onProgress: ((Double) -> Void)?  // 0.0 ~ 1.0

    /// 识别错误回调
    var onError: ((Error) -> Void)?

    // MARK: - Public Methods

    /// 从视频文件进行语音识别
    /// - Parameter videoURL: 视频文件 URL
    /// - Returns: 带时间戳的字幕数组
    func recognizeSpeech(from videoURL: URL) async throws -> [SubtitleItem] {
        // Step 1: 从视频中提取音频
        let audioURL = try await extractAudio(from: videoURL)

        // Step 2: 进行语音识别
        let subtitles = try await performSpeechRecognition(on: audioURL)

        // Step 3: 清理临时音频文件
        try? FileManager.default.removeItem(at: audioURL)

        return subtitles
    }

    /// 检查语音识别权限
    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// 获取授权状态描述
    func authorizationStatusDescription(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "已授权"
        case .denied:
            return "已拒绝，请在系统设置中开启语音识别权限"
        case .restricted:
            return "受限制，此设备不支持语音识别"
        case .notDetermined:
            return "未请求权限"
        @unknown default:
            return "未知状态"
        }
    }

    // MARK: - Private Methods - Audio Extraction

    /// 从视频中提取音频轨道
    private func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVAsset(url: videoURL)

        // 获取音频轨道
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw SpeechRecognitionError.noAudioTrack
        }

        // 创建临时输出文件
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        // 使用 AVAssetExportSession 导出音频
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw SpeechRecognitionError.exportSessionCreationFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(start: .zero, duration: try await asset.load(.duration))

        await exportSession.export()

        guard exportSession.status == .completed else {
            if let error = exportSession.error {
                throw SpeechRecognitionError.audioExtractionFailed(error)
            }
            throw SpeechRecognitionError.audioExtractionFailed(nil)
        }

        return outputURL
    }

    // MARK: - Private Methods - Speech Recognition

    /// 执行语音识别
    private func performSpeechRecognition(on audioURL: URL) async throws -> [SubtitleItem] {
        return try await withCheckedThrowingContinuation { continuation in
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
            guard let recognizer = recognizer, recognizer.isAvailable else {
                continuation.resume(throwing: SpeechRecognitionError.recognizerUnavailable)
                return
            }

            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = false
            // 如果识别结果不是中文，需要在后续翻译
            // 强制使用中文识别（Apple 的模型会尽量识别为中文）
            request.requiresOnDeviceRecognition = false  // 允许使用服务器

            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: SpeechRecognitionError.recognitionFailed(error))
                    return
                }

                guard let result = result, result.isFinal else {
                    return  // 等待最终结果
                }

                // 解析识别结果，生成带时间戳的字幕
                let subtitles = self.parseRecognitionResult(result)
                continuation.resume(returning: subtitles)
            }
        }
    }

    /// 解析语音识别结果为字幕
    ///
    /// Apple Speech Framework 提供的结果包含 segments（段落），
    /// 每个 segment 包含时间信息和转录文本。
    /// 也支持按句子或词级别分割。
    private func parseRecognitionResult(_ result: SFSpeechRecognitionResult) -> [SubtitleItem] {
        var subtitles: [SubtitleItem] = []

        // 使用 segments 获取更精确的时间戳
        for segment in result.bestTranscription.segments {
            // 每个 segment 是词级别还是句子级别取决于音频内容
            // 将相邻的小片段合并，或直接使用每个 segment

            let text = segment.substring.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            let subtitle = SubtitleItem(
                startTime: segment.timestamp,
                endTime: segment.timestamp + segment.duration,
                originalText: text,
                language: "zh-Hans",
                source: .speechRecognition
            )
            subtitles.append(subtitle)
        }

        // 合并相邻的短字幕（小于 1.5 秒的字幕合并）
        let merged = mergeShortSubtitles(subtitles, minDuration: 1.5)

        return merged
    }

    /// 合并短字幕
    private func mergeShortSubtitles(_ subtitles: [SubtitleItem], minDuration: TimeInterval) -> [SubtitleItem] {
        guard !subtitles.isEmpty else { return [] }

        var merged: [SubtitleItem] = []
        var currentText: [String] = []
        var currentStart: TimeInterval = subtitles[0].startTime
        var currentEnd: TimeInterval = subtitles[0].endTime

        for subtitle in subtitles {
            if currentEnd - currentStart < minDuration {
                // 合并
                currentText.append(subtitle.originalText)
                currentEnd = subtitle.endTime
            } else {
                // 保存当前合并的字幕
                if !currentText.isEmpty {
                    let mergedSubtitle = SubtitleItem(
                        startTime: currentStart,
                        endTime: currentEnd,
                        originalText: currentText.joined(separator: " "),
                        language: "zh-Hans",
                        source: .speechRecognition
                    )
                    merged.append(mergedSubtitle)
                }

                // 开始新字幕
                currentText = [subtitle.originalText]
                currentStart = subtitle.startTime
                currentEnd = subtitle.endTime
            }
        }

        // 处理最后一条
        if !currentText.isEmpty {
            let mergedSubtitle = SubtitleItem(
                startTime: currentStart,
                endTime: currentEnd,
                originalText: currentText.joined(separator: " "),
                language: "zh-Hans",
                source: .speechRecognition
            )
            merged.append(mergedSubtitle)
        }

        return merged
    }
}

// MARK: - Speech Recognition Error Types

enum SpeechRecognitionError: LocalizedError {
    case noAudioTrack
    case exportSessionCreationFailed
    case audioExtractionFailed(Error?)
    case recognizerUnavailable
    case recognitionFailed(Error)
    case permissionDenied
    case languageNotSupported(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return "视频中没有找到音频轨道"
        case .exportSessionCreationFailed:
            return "无法创建音频导出会话"
        case .audioExtractionFailed(let error):
            return "音频提取失败: \(error?.localizedDescription ?? "未知错误")"
        case .recognizerUnavailable:
            return "语音识别器不可用，请检查网络连接或系统设置"
        case .recognitionFailed(let error):
            return "语音识别失败: \(error.localizedDescription)"
        case .permissionDenied:
            return "语音识别权限被拒绝，请在系统设置中开启"
        case .languageNotSupported(let lang):
            return "不支持的语言: \(lang)"
        case .networkError(let detail):
            return "网络错误: \(detail)"
        }
    }
}
