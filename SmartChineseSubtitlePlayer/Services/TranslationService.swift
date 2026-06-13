import Foundation

/// 翻译服务协议
/// 定义翻译服务的标准接口，便于后续接入不同的翻译 API
protocol TranslationServiceProtocol {
    /// 翻译单段文本为简体中文
    /// - Parameter text: 源文本
    /// - Parameter sourceLanguage: 源语言代码
    /// - Returns: 翻译后的中文文本
    func translate(_ text: String, from sourceLanguage: String) async throws -> String

    /// 批量翻译多段文本
    /// - Parameter texts: 源文本数组
    /// - Parameter sourceLanguage: 源语言代码
    /// - Returns: 翻译后的中文文本数组
    func translateBatch(_ texts: [String], from sourceLanguage: String) async throws -> [String]
}

/// 翻译服务实现
///
/// ## 当前状态：Mock 实现
/// 当前使用本地 Mock 翻译（简单的词典替换 + 标记），用于 Demo 和测试。
///
/// ## TODO: 接入真实翻译 API
///
/// ### 方案 A：Apple Translation Framework（iOS 18+）
/// ```swift
/// import Translation
/// let session = Translator.translationSession()
/// let response = try await session.translate(text, from: sourceLanguage, to: .chineseSimplified)
/// ```
///
/// ### 方案 B：Google Cloud Translation API
/// ```swift
/// // 1. 在 Google Cloud Console 启用 Cloud Translation API
/// // 2. 获取 API Key
/// // 3. 调用 REST API:
/// let url = URL(string: "https://translation.googleapis.com/language/translate/v2")!
/// var request = URLRequest(url: url)
/// request.httpMethod = "POST"
/// request.setValue("application/json", forHTTPHeaderField: "Content-Type")
/// let body: [String: Any] = [
///     "q": texts,
///     "target": "zh-CN",
///     "source": sourceLanguage,
///     "key": apiKey
/// ]
/// request.httpBody = try JSONSerialization.data(withJSONObject: body)
/// ```
///
/// ### 方案 C：DeepL API
/// ```swift
/// // DeepL 对亚洲语言支持较好
/// let url = URL(string: "https://api-free.deepl.com/v2/translate")!
/// // Headers: Authorization: DeepL-Auth-Key <your-key>
/// ```
///
/// ### 方案 D：Microsoft Azure Translator
/// ```swift
/// // Azure 翻译服务
/// let url = URL(string: "https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&to=zh-Hans")!
/// // Headers: Ocp-Apim-Subscription-Key: <your-key>
/// ```
final class TranslationService: TranslationServiceProtocol {

    // MARK: - Singleton

    static let shared = TranslationService()

    private init() {}

    // MARK: - Properties

    /// 翻译状态回调
    var onTranslationProgress: ((Int, Int) -> Void)?  // (completed, total)

    // MARK: - Public Methods

    /// 翻译单段文本为简体中文
    func translate(_ text: String, from sourceLanguage: String) async throws -> String {
        guard !text.isEmpty else { return text }

        // 如果是中文则不需要翻译
        if sourceLanguage.hasPrefix("zh") {
            return text
        }

        // TODO: 替换为真实翻译 API 调用
        // 目前使用 Mock 翻译
        return mockTranslate(text, from: sourceLanguage)
    }

    /// 批量翻译多段文本
    func translateBatch(_ texts: [String], from sourceLanguage: String) async throws -> [String] {
        guard !texts.isEmpty else { return [] }

        // 中文不需要翻译
        if sourceLanguage.hasPrefix("zh") {
            return texts
        }

        var results: [String] = []
        results.reserveCapacity(texts.count)

        for (index, text) in texts.enumerated() {
            let translated = try await translate(text, from: sourceLanguage)
            results.append(translated)

            // 通知进度
            await MainActor.run {
                onTranslationProgress?(index + 1, texts.count)
            }
        }

        return results
    }

    /// 翻译字幕数组
    /// - Parameter subtitles: 待翻译的字幕数组
    /// - Parameter sourceLanguage: 源语言（如果为 nil 则自动检测）
    /// - Returns: 翻译后的字幕数组
    func translateSubtitles(
        _ subtitles: [SubtitleItem],
        from sourceLanguage: String? = nil
    ) async throws -> [SubtitleItem] {
        guard !subtitles.isEmpty else { return [] }

        // 检测语言
        let language: String
        if let sourceLanguage = sourceLanguage {
            language = sourceLanguage
        } else {
            let allText = subtitles.map { $0.originalText }.joined(separator: " ")
            language = LanguageDetectionService.shared.detectLanguage(of: allText)
        }

        // 如果是中文，标记语言后直接返回
        if language.hasPrefix("zh") {
            return subtitles.map { subtitle in
                var updated = subtitle
                updated.language = language
                updated.translatedText = nil
                return updated
            }
        }

        // 批量翻译
        let originalTexts = subtitles.map { $0.originalText }
        let translatedTexts = try await translateBatch(originalTexts, from: language)

        // 更新字幕
        return zip(subtitles, translatedTexts).map { subtitle, translatedText in
            var updated = subtitle
            updated.language = language
            updated.translatedText = translatedText
            updated.isMachineTranslated = true
            return updated
        }
    }

    // MARK: - Mock Translation

    /// Mock 翻译方法
    /// 用于开发和测试，实际生产应替换为真实 API
    private func mockTranslate(_ text: String, from sourceLanguage: String) -> String {
        // 模拟网络延迟
        // 在实际实现中，应替换为真实的网络请求

        // 基础词典（用于 Demo）
        let mockDictionary: [String: [String: String]] = [
            "en": [
                "hello": "你好",
                "thank you": "谢谢",
                "good morning": "早上好",
                "goodbye": "再见",
                "how are you": "你好吗",
                "I'm fine": "我很好",
                "nice to meet you": "很高兴认识你",
                "sorry": "对不起",
                "yes": "是的",
                "no": "不是",
                "please": "请",
                "excuse me": "打扰一下",
                "welcome": "欢迎",
                "good night": "晚安",
                "see you later": "待会见",
            ],
            "ja": [
                "こんにちは": "你好",
                "ありがとう": "谢谢",
                "おはよう": "早上好",
                "さようなら": "再见",
                "すみません": "对不起",
            ],
            "ko": [
                "안녕하세요": "你好",
                "감사합니다": "谢谢",
                "좋은 아침": "早上好",
                "안녕히 가세요": "再见",
                "미안합니다": "对不起",
            ]
        ]

        // 尝试词典翻译
        let lowercasedText = text.lowercased()
        if let dict = mockDictionary[sourceLanguage],
           let translation = dict[lowercasedText] {
            return translation
        }

        // 简短的 Mock 翻译标记
        return "[译] \(text)"
    }
}
