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

enum Insertion: String {
    /// The word being typed is underlined marked text that the app holds until commit.
    case marked
    /// The word is plain text that each key replaces. Nothing is pending, so shortcuts see all of it.
    case direct
}

/// What Ankey does in one app: stays out of the way, or composes with one of the two insertions.
enum AppMode {
    case off, marked, direct
}

/// How Ankey behaves in one app.
struct AppRule: Equatable {
    var bundleID: String
    var enabled = true
    var insertion = Insertion.marked

    /// The single choice behind `enabled` and `insertion`. Turning it off keeps the last insertion.
    var mode: AppMode {
        get { !enabled ? .off : insertion == .direct ? .direct : .marked }
        set {
            enabled = newValue != .off
            switch newValue {
            case .off: break
            case .marked: insertion = .marked
            case .direct: insertion = .direct
            }
        }
    }

    /// Trimmed IDs, empty ones dropped, first rule of an ID wins.
    static func cleaned(_ rules: [AppRule]) -> [AppRule] {
        var seen = Set<String>()
        var result: [AppRule] = []
        for var rule in rules {
            rule.bundleID = rule.bundleID.trimmingCharacters(in: .whitespaces)
            if !rule.bundleID.isEmpty, seen.insert(rule.bundleID).inserted { result.append(rule) }
        }
        return result
    }

    init(bundleID: String, enabled: Bool = true, insertion: Insertion = .marked) {
        self.bundleID = bundleID
        self.enabled = enabled
        self.insertion = insertion
    }

    init?(stored row: [String: Any]) {
        guard let bundleID = row["bundleID"] as? String else { return nil }
        self.init(
            bundleID: bundleID,
            enabled: row["enabled"] as? Bool ?? true,
            insertion: (row["insertion"] as? String).flatMap(Insertion.init(rawValue:)) ?? .marked
        )
    }

    var stored: [String: Any] {
        ["bundleID": bundleID, "enabled": enabled, "insertion": insertion.rawValue]
    }
}

struct Settings: Equatable {
    var toneStyle = ToneStyle.modern
    var restoreRaw = true
    var abbreviation = true
    var escClears = true
    var macros: [Macro] = []
    var shorthand = ["\u{0111}c"]
    /// The user's own English words, on top of the built-in `English` lists. Typed keys, lowercase.
    var keepEnglish: [String] = []
    var appRules: [AppRule] = []
}

extension Settings {
    private enum Key {
        static let toneStyle = "toneStyle"
        static let restoreRaw = "restoreRaw"
        static let abbreviation = "abbreviation"
        static let escClears = "escClears"
        static let macros = "macros"
        static let shorthand = "shorthand"
        static let keepEnglish = "keepEnglish"
        static let appRules = "appRules"
        static let excludedApps = "excludedApps"
    }

    /// The rule for an app. An unknown client, or one without a bundle ID, gets the default rule.
    func rule(for bundleID: String?) -> AppRule {
        appRules.first { $0.bundleID == bundleID } ?? AppRule(bundleID: bundleID ?? "")
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
        if let words = defaults.stringArray(forKey: Key.keepEnglish) {
            settings.keepEnglish = uniqueTrimmed(words, lowercased: true)
        }
        if let rows = defaults.array(forKey: Key.appRules) as? [[String: Any]] {
            settings.appRules = AppRule.cleaned(rows.compactMap(AppRule.init(stored:)))
        } else if let apps = defaults.stringArray(forKey: Key.excludedApps) {
            // Apps excluded before per-app rules existed keep Ankey off.
            settings.appRules = AppRule.cleaned(apps.map { AppRule(bundleID: $0, enabled: false) })
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
        defaults.set(keepEnglish, forKey: Key.keepEnglish)
        defaults.set(appRules.map(\.stored), forKey: Key.appRules)
        defaults.removeObject(forKey: Key.excludedApps)
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
