import Foundation

enum ToneStyle: String {
    /// Kiểu mới: hoà, thuý.
    case modern
    /// Kiểu cũ: hòa, thúy.
    case classic
}

/// A text-expansion entry. `id` exists only while the app runs; two macros are equal
/// when the saved fields match.
struct Macro: Equatable, Identifiable {
    var id = UUID()
    var shortcut: String
    var text: String

    static func == (lhs: Macro, rhs: Macro) -> Bool {
        lhs.shortcut == rhs.shortcut && lhs.text == rhs.text
    }
}

extension Macro {
    enum Problem {
        case badShortcut
        case emptyText
        case duplicate
    }

    /// The shortcut as the engine matches it: trimmed, lowercase.
    var normalizedShortcut: String {
        shortcut.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// The single rule set for a usable table. The window shows these problems and
    /// `cleaned` drops the same rows. The first valid row of a shortcut wins.
    static func problems(in macros: [Macro]) -> [UUID: Problem] {
        var seen = Set<String>()
        var result: [UUID: Problem] = [:]
        for macro in macros {
            let key = macro.normalizedShortcut
            if key.isEmpty || !key.allSatisfy({ $0.isASCII && $0.isLetter }) {
                result[macro.id] = .badShortcut
            } else if macro.text.isEmpty {
                result[macro.id] = .emptyText
            } else if !seen.insert(key).inserted {
                result[macro.id] = .duplicate
            }
        }
        return result
    }

    static func cleaned(_ macros: [Macro]) -> [Macro] {
        let problems = problems(in: macros)
        return macros
            .filter { problems[$0.id] == nil }
            .map { Macro(id: $0.id, shortcut: $0.normalizedShortcut, text: $0.text) }
    }
}

struct Settings: Equatable {
    var toneStyle = ToneStyle.modern
    var restoreRaw = true
    var abbreviation = true
    var escClears = true
    var macros: [Macro] = []
    var shorthand = ["\u{0111}c"]
    var excludedApps: [String] = []
}

extension Settings {
    private enum Key {
        static let toneStyle = "toneStyle"
        static let restoreRaw = "restoreRaw"
        static let abbreviation = "abbreviation"
        static let escClears = "escClears"
        static let macros = "macros"
        static let shorthand = "shorthand"
        static let excludedApps = "excludedApps"
    }

    /// An unknown client, or one without a bundle ID, is never excluded.
    func isExcluded(bundleID: String?) -> Bool {
        guard let bundleID, !bundleID.isEmpty else { return false }
        return excludedApps.contains(bundleID)
    }

    /// A key that was never saved, or holds the wrong type, keeps its default.
    static func load(from defaults: UserDefaults = .standard) -> Settings {
        var settings = Settings()
        if let raw = defaults.string(forKey: Key.toneStyle), let style = ToneStyle(rawValue: raw) {
            settings.toneStyle = style
        }
        settings.restoreRaw = defaults.object(forKey: Key.restoreRaw) as? Bool ?? settings.restoreRaw
        settings.abbreviation = defaults.object(forKey: Key.abbreviation) as? Bool ?? settings.abbreviation
        settings.escClears = defaults.object(forKey: Key.escClears) as? Bool ?? settings.escClears
        if let rows = defaults.array(forKey: Key.macros) as? [[String: String]] {
            let macros = rows.compactMap { row -> Macro? in
                guard let shortcut = row["shortcut"], let text = row["text"] else { return nil }
                return Macro(shortcut: shortcut, text: text)
            }
            settings.macros = Macro.cleaned(macros)
        }
        if let words = defaults.stringArray(forKey: Key.shorthand) {
            settings.shorthand = uniqueTrimmed(words, lowercased: true)
        }
        if let apps = defaults.stringArray(forKey: Key.excludedApps) {
            settings.excludedApps = uniqueTrimmed(apps, lowercased: false)
        }
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(toneStyle.rawValue, forKey: Key.toneStyle)
        defaults.set(restoreRaw, forKey: Key.restoreRaw)
        defaults.set(abbreviation, forKey: Key.abbreviation)
        defaults.set(escClears, forKey: Key.escClears)
        defaults.set(macros.map { ["shortcut": $0.shortcut, "text": $0.text] }, forKey: Key.macros)
        defaults.set(shorthand, forKey: Key.shorthand)
        defaults.set(excludedApps, forKey: Key.excludedApps)
    }

    private static func uniqueTrimmed(_ items: [String], lowercased: Bool) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in items {
            let trimmed = item.trimmingCharacters(in: .whitespaces)
            let value = lowercased ? trimmed.lowercased() : trimmed
            if !value.isEmpty, seen.insert(value).inserted { result.append(value) }
        }
        return result
    }
}
