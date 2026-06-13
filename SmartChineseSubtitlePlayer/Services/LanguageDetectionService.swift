import Foundation
import NaturalLanguage

/// 语言检测服务
/// 自动检测文本的语言，判断是否为中文
final class LanguageDetectionService {

    // MARK: - Singleton

    static let shared = LanguageDetectionService()

    private init() {}

    // MARK: - Public Methods

    /// 检测单段文本的语言
    /// - Parameter text: 待检测文本
    /// - Returns: 语言代码（如 "zh-Hans", "en", "ja", "ko"）
    func detectLanguage(of text: String) -> String {
        guard !text.isEmpty else { return "unknown" }

        // 使用 NLLanguageRecognizer 进行语言识别
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        if let language = recognizer.dominantLanguage {
            return language.rawValue
        }

        // 回退：检测是否包含中文字符
        if containsChineseCharacters(text) {
            return "zh-Hans"
        }

        return "unknown"
    }

    /// 判断文本是否为中文
    /// - Parameter text: 待判断文本
    /// - Returns: 是否为中文
    func isChinese(_ text: String) -> Bool {
        let language = detectLanguage(of: text)
        return language.hasPrefix("zh")
    }

    /// 批量检测多段文本的语言（仅当置信度不足时使用）
    /// - Parameter texts: 文本数组
    /// - Returns: 主要语言代码
    func detectPrimaryLanguage(of texts: [String]) -> String {
        let combinedText = texts.joined(separator: " ")

        guard combinedText.count > 10 else {
            // 文本太短，逐条检测后投票
            return voteLanguage(texts)
        }

        return detectLanguage(of: combinedText)
    }

    /// 获取语言的显示名称
    /// - Parameter languageCode: 语言代码
    /// - Returns: 显示名称
    func displayName(for languageCode: String) -> String {
        switch languageCode {
        case "zh-Hans", "zh-Hant", "zh":
            return "中文"
        case "en":
            return "英语"
        case "ja":
            return "日语"
        case "ko":
            return "韩语"
        case "fr":
            return "法语"
        case "de":
            return "德语"
        case "es":
            return "西班牙语"
        case "pt":
            return "葡萄牙语"
        case "ru":
            return "俄语"
        case "ar":
            return "阿拉伯语"
        case "th":
            return "泰语"
        case "vi":
            return "越南语"
        case "it":
            return "意大利语"
        default:
            if languageCode.hasPrefix("zh") {
                return "中文"
            }
            return languageCode
        }
    }

    // MARK: - Private Methods

    /// 检查文本是否包含中文字符
    private func containsChineseCharacters(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            // CJK统一汉字范围
            if (0x4E00...0x9FFF).contains(scalar.value) ||
               (0x3400...0x4DBF).contains(scalar.value) ||  // CJK扩展A
               (0x20000...0x2A6DF).contains(scalar.value) {  // CJK扩展B
                return true
            }
        }
        return false
    }

    /// 投票选出主要语言
    private func voteLanguage(_ texts: [String]) -> String {
        var votes: [String: Int] = [:]

        for text in texts {
            let lang = detectLanguage(of: text)
            votes[lang, default: 0] += 1
        }

        return votes.max(by: { $0.value < $1.value })?.key ?? "unknown"
    }
}
