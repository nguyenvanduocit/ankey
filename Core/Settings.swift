import Foundation

enum ToneStyle: String {
    /// Kiểu mới: hoà, thuý.
    case modern
    /// Kiểu cũ: hòa, thúy.
    case classic
}

enum Insertion: String {
    /// The word being typed is underlined marked text that the app holds until commit.
    case marked
    /// The word is plain text that each key replaces. Nothing is pending, so shortcuts see all of it. Backspace
    /// is the app's own: it takes out the last character on screen, not the last Telex key (`DirectWord`).
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
    /// Offers the rest of a phrase when the words just typed can only go on one way.
    var suggestions = true
    /// Counts the phrases typed and suggests the ones typed the same way again and again. Off until the user
    /// turns it on, because it keeps words the user typed (on this Mac only).
    var learnsPhrases = false
    /// Learns which language the user writes after which word, and reads it when a word could be either. Off
    /// until the user turns it on, because it keeps words the user typed (on this Mac only).
    var learnsLanguage = false
    /// Keeps a diary of the words the user took back (Esc, Shift+Esc, erase and retype) with the app they were
    /// typed in, for the user's AI to read. Off until the user turns it on, because it keeps words the user
    /// typed (on this Mac only, never sent).
    var keepsDiary = false
    var shorthand = ["\u{0111}c"]
    /// Sequences the Telex engine never recognises that the user always means as a specific Vietnamese word.
    /// Matched at word commit before Telex runs. Stored as `[sequence: word]`, keys are ASCII-letter lowercase.
    var customMap: [String: String] = [:]
    /// What Ankey learned from corrections: a score per word, added to its built-in band. Typed keys,
    /// lowercase. `Settings.load` fills it from the `AdjustStore`, and `save` never writes it.
    var adjust: [String: Int] = [:]
    /// Which language the user writes after which word. `Settings.load` fills it from the `LanguageHabitsStore`
    /// when `learnsLanguage` is on, and `save` never writes it.
    var habits = LanguageHabits()
    var appRules: [AppRule] = []
    /// Counts events on this machine for the statistics tab. Off until the user turns it on.
    var collectStats = false
    /// Sends the counters to Datadog once a day. Needs `collectStats`, off until the user turns it on.
    var shareStats = false
    /// The guide has had its first showing. It stays in the input menu after that.
    var onboardingSeen = false
}

extension Settings {
    private enum Key {
        static let toneStyle = "toneStyle"
        static let restoreRaw = "restoreRaw"
        static let abbreviation = "abbreviation"
        static let escClears = "escClears"
        static let suggestions = "suggestions"
        static let learnsPhrases = "learnsPhrases"
        static let learnsLanguage = "learnsLanguage"
        static let keepsDiary = "keepsDiary"
        static let shorthand = "shorthand"
        static let customMap = "customMap"
        static let appRules = "appRules"
        static let excludedApps = "excludedApps"
        static let collectStats = "collectStats"
        static let shareStats = "shareStats"
        static let onboardingSeen = "onboardingSeen"
    }

    /// Writes only this flag, so the first launch does not save every other default with it.
    static func markOnboardingSeen(in defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: Key.onboardingSeen)
    }

    /// One bool read, so the key path can ask before it counts anything.
    static func collectsStats(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: Key.collectStats)
    }

    /// One bool read, so the key path can ask before it writes a word down.
    static func keepsDiary(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: Key.keepsDiary)
    }

    /// The rule for an app. An unknown client, or one without a bundle ID, gets the default rule.
    func rule(for bundleID: String?) -> AppRule {
        appRules.first { $0.bundleID == bundleID } ?? AppRule(bundleID: bundleID ?? "")
    }

    /// A key that was never saved, or holds the wrong type, keeps its default.
    static func load(from defaults: UserDefaults = .standard, adjust: AdjustStore = .shared) -> Settings {
        var settings = Settings()
        settings.adjust = adjust.words
        if let raw = defaults.string(forKey: Key.toneStyle), let style = ToneStyle(rawValue: raw) {
            settings.toneStyle = style
        }
        settings.restoreRaw = defaults.object(forKey: Key.restoreRaw) as? Bool ?? settings.restoreRaw
        settings.abbreviation = defaults.object(forKey: Key.abbreviation) as? Bool ?? settings.abbreviation
        settings.escClears = defaults.object(forKey: Key.escClears) as? Bool ?? settings.escClears
        settings.suggestions = defaults.object(forKey: Key.suggestions) as? Bool ?? settings.suggestions
        settings.learnsPhrases = defaults.object(forKey: Key.learnsPhrases) as? Bool ?? settings.learnsPhrases
        settings.learnsLanguage = defaults.object(forKey: Key.learnsLanguage) as? Bool ?? settings.learnsLanguage
        settings.keepsDiary = keepsDiary(in: defaults)
        settings.collectStats = collectsStats(in: defaults)
        settings.shareStats = settings.collectStats && defaults.bool(forKey: Key.shareStats)
        settings.onboardingSeen = defaults.bool(forKey: Key.onboardingSeen)
        if let words = defaults.stringArray(forKey: Key.shorthand) {
            settings.shorthand = uniqueTrimmed(words, lowercased: true)
        }
        if let raw = defaults.dictionary(forKey: Key.customMap) {
            settings.customMap = raw.compactMapValues { $0 as? String }
                .filter { !$0.key.isEmpty && !$0.value.isEmpty }
        }
        if let rows = defaults.array(forKey: Key.appRules) as? [[String: Any]] {
            settings.appRules = AppRule.cleaned(rows.compactMap(AppRule.init(stored:)))
        } else if let apps = defaults.stringArray(forKey: Key.excludedApps) {
            // Apps excluded before per-app rules existed keep Ankey off.
            settings.appRules = AppRule.cleaned(apps.map { AppRule(bundleID: $0, enabled: false) })
        }
        return settings
    }

    /// With `old`, writes only the keys that differ from it. A window holds a copy from when it was built, and
    /// writing every key from that copy would take back a change another process made to a key the window did
    /// not touch.
    func save(to defaults: UserDefaults = .standard, replacing old: Settings? = nil) {
        func put<Value: Equatable>(_ path: KeyPath<Settings, Value>, _ key: String, as stored: (Value) -> Any = { $0 }) {
            if let old, old[keyPath: path] == self[keyPath: path] { return }
            defaults.set(stored(self[keyPath: path]), forKey: key)
        }
        put(\.toneStyle, Key.toneStyle) { $0.rawValue }
        put(\.restoreRaw, Key.restoreRaw)
        put(\.abbreviation, Key.abbreviation)
        put(\.escClears, Key.escClears)
        put(\.suggestions, Key.suggestions)
        put(\.learnsPhrases, Key.learnsPhrases)
        put(\.learnsLanguage, Key.learnsLanguage)
        put(\.keepsDiary, Key.keepsDiary)
        put(\.collectStats, Key.collectStats)
        // Loading reads sharing as off while collection is off, so a window's copy says off there. Writing it
        // whenever collection changes keeps a `true` stored earlier from coming back when collection is turned on.
        if old.map({ $0.shareStats != shareStats || $0.collectStats != collectStats }) ?? true {
            defaults.set(shareStats, forKey: Key.shareStats)
        }
        put(\.onboardingSeen, Key.onboardingSeen)
        put(\.shorthand, Key.shorthand)
        put(\.customMap, Key.customMap)
        put(\.appRules, Key.appRules) { $0.map(\.stored) }
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
