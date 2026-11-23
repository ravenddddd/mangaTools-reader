import Foundation

/// How the plugin's language codes are written on screen.
///
/// Native names on purpose: the shelf mixes Japanese, Chinese and English works,
/// and "日本語" reads the same to everyone, while "Japanese" depends on the
/// interface language. `zxx` is ISO 639-2's "no linguistic content" — a CG
/// collection, an art book — which the plugin treats as a value, not an absence.
enum LanguageName {
    private static let names: [String: String] = [
        "ja": "日本語",
        "zh-Hans": "简体中文",
        "zh-Hant": "繁體中文",
        "en": "English",
        "ko": "한국어",
        "es": "Español",
        "fr": "Français",
        "de": "Deutsch",
        "it": "Italiano",
        "pt": "Português",
        "ru": "Русский",
        "th": "ไทย",
        "vi": "Tiếng Việt",
        "id": "Bahasa Indonesia",
        "zxx": "No language",
    ]

    static func display(_ code: String?) -> String? {
        guard let code = code?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty else {
            return nil
        }
        if let name = names[code] {
            return name
        }
        if let match = names.first(where: { $0.key.caseInsensitiveCompare(code) == .orderedSame }) {
            return match.value
        }
        return Locale.current.localizedString(forLanguageCode: code) ?? code
    }
}

/// The two values the plugin writes into its censorship field, and the
/// capitalisation a sentence wants.
enum Censorship {
    static func label(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        switch raw.lowercased() {
        case "censored": return "Censored"
        case "uncensored": return "Uncensored"
        default: return String(raw.prefix(1)).uppercased() + String(raw.dropFirst())
        }
    }

    static func isUncensored(_ raw: String?) -> Bool {
        raw?.lowercased() == "uncensored"
    }
}
