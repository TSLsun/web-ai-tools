import Foundation

enum Language: String, CaseIterable, Codable {
    case zhTW = "zh-TW"
    case enUS = "en-US"
    case ja = "ja"
    case de = "de"

    static let `default`: Language = .zhTW

    var displayName: String {
        switch self {
        case .zhTW: return "繁體中文"
        case .enUS: return "English"
        case .ja: return "日本語"
        case .de: return "Deutsch"
        }
    }
}
