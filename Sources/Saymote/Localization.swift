import Foundation

enum AppLanguage: String, CaseIterable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    private static let defaultsKey = "saymote.appLanguage"
    private static let legacyDefaultsKey = "vRemoter.appLanguage"

    static var selected: AppLanguage {
        get {
            let defaults = UserDefaults.standard
            let raw = defaults.string(forKey: defaultsKey) ?? defaults.string(forKey: legacyDefaultsKey)
            guard let raw, let language = AppLanguage(rawValue: raw) else {
                return .system
            }
            return language
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey) }
    }

    var usesEnglish: Bool {
        switch self {
        case .english:
            return true
        case .simplifiedChinese:
            return false
        case .system:
            return !(Locale.preferredLanguages.first ?? "zh-Hans").hasPrefix("zh")
        }
    }
}

enum L10n {
    static func text(_ simplifiedChinese: String, _ english: String) -> String {
        AppLanguage.selected.usesEnglish ? english : simplifiedChinese
    }
}
