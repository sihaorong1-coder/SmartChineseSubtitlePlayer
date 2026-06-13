import Foundation

// MARK: - String Language Detection

extension String {

    /// 检查字符串是否包含中文字符
    var containsChineseCharacters: Bool {
        for scalar in unicodeScalars {
            if CharacterSet.cjkUnifiedIdeographs.contains(scalar) ||
               CharacterSet.cjkCompatibilityIdeographs.contains(scalar) ||
               CharacterSet.cjkRadicalsSupplement.contains(scalar) {
                return true
            }
        }
        return false
    }

    /// 检查字符串是否包含日文字符（平假名、片假名）
    var containsJapaneseCharacters: Bool {
        for scalar in unicodeScalars {
            if (0x3040...0x309F).contains(scalar.value) ||  // 平假名
               (0x30A0...0x30FF).contains(scalar.value) {   // 片假名
                return true
            }
        }
        return false
    }

    /// 检查字符串是否包含韩文字符
    var containsKoreanCharacters: Bool {
        for scalar in unicodeScalars {
            if (0xAC00...0xD7AF).contains(scalar.value) ||  // 韩文音节
               (0x1100...0x11FF).contains(scalar.value) {   // 韩文字母
                return true
            }
        }
        return false
    }

    /// 估计主要语言
    var estimatedLanguage: String {
        if containsChineseCharacters {
            return containsJapaneseCharacters ? "ja" : "zh-Hans"
        }
        if containsKoreanCharacters {
            return "ko"
        }
        // 使用 NaturalLanguage 框架进行更准确的检测
        if #available(iOS 12.0, *) {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(self)
            if let language = recognizer.dominantLanguage {
                return language.rawValue
            }
        }
        return "unknown"
    }
}

// MARK: - CharacterSet Extensions

extension CharacterSet {
    /// CJK 统一汉字
    static let cjkUnifiedIdeographs = CharacterSet(charactersIn: UnicodeScalar(0x4E00)!...UnicodeScalar(0x9FFF)!)

    /// CJK 兼容汉字
    static let cjkCompatibilityIdeographs = CharacterSet(charactersIn: UnicodeScalar(0xF900)!...UnicodeScalar(0xFAFF)!)

    /// CJK 部首补充
    static let cjkRadicalsSupplement = CharacterSet(charactersIn: UnicodeScalar(0x2E80)!...UnicodeScalar(0x2EFF)!)
}
