import Foundation

/// A setting the command line can name.
enum SettingKey: String, CaseIterable {
    case toneStyle, restoreRaw, abbreviation, escClears, suggestions
    case learnsPhrases, learnsLanguage, collectStats, shareStats, keepsDiary

    /// These keep or send what the user typed. An AI may switch them off and never on: only the user does that.
    var humanOnly: Bool {
        switch self {
        case .learnsPhrases, .learnsLanguage, .collectStats, .shareStats, .keepsDiary: return true
        case .toneStyle, .restoreRaw, .abbreviation, .escClears, .suggestions: return false
        }
    }

    var choices: [String] {
        self == .toneStyle ? ["modern", "classic"] : ["on", "off"]
    }

    /// The Settings tab where the user finds the switch.
    var tab: String {
        switch self {
        case .toneStyle, .restoreRaw, .escClears: return "Chung"
        case .abbreviation: return "Vi\u{1ebf}t t\u{1eaf}t"
        case .collectStats, .shareStats: return "Th\u{1ed1}ng k\u{00ea}"
        case .suggestions, .learnsPhrases, .learnsLanguage, .keepsDiary: return "AI"
        }
    }

    private var flag: WritableKeyPath<Settings, Bool>? {
        switch self {
        case .toneStyle: return nil
        case .restoreRaw: return \.restoreRaw
        case .abbreviation: return \.abbreviation
        case .escClears: return \.escClears
        case .suggestions: return \.suggestions
        case .learnsPhrases: return \.learnsPhrases
        case .learnsLanguage: return \.learnsLanguage
        case .collectStats: return \.collectStats
        case .shareStats: return \.shareStats
        case .keepsDiary: return \.keepsDiary
        }
    }

    func value(in settings: Settings) -> String {
        if let flag { return settings[keyPath: flag] ? "on" : "off" }
        return settings.toneStyle.rawValue
    }

    func assign(_ text: String, in settings: inout Settings) {
        if let flag {
            settings[keyPath: flag] = text == "on"
        } else if let style = ToneStyle(rawValue: text) {
            settings.toneStyle = style
        }
    }
}

extension AppMode {
    static let names = ["off", "marked", "direct"]

    init?(name: String) {
        switch name {
        case "off": self = .off
        case "marked": self = .marked
        case "direct": self = .direct
        default: return nil
        }
    }

    var name: String {
        switch self {
        case .off: return "off"
        case .marked: return "marked"
        case .direct: return "direct"
        }
    }
}

/// One edit to the settings. The edit that undoes it is another `ConfigEdit`, so the change log stores plain data.
struct ConfigEdit: Codable, Equatable {
    enum Kind: String, Codable {
        case set, shorthandAdd, shorthandRemove, appRule, appRuleRemove
    }

    var kind: Kind
    /// The setting name, the shorthand word or the bundle ID, by `kind`.
    var key: String
    /// The new value of a setting, or the mode of an app rule.
    var value: String?
}

/// What an edit did, in words, with the edit that puts it back. A change with no `undo` is one the user alone
/// may reverse.
struct Change: Codable, Equatable {
    var time: Date
    var summary: String
    var undo: ConfigEdit?
}

/// The changes made through the command line, oldest first, so the user can see them and take one back.
struct ChangeLog: Codable, Equatable {
    static let capacity = 50

    private(set) var changes: [Change] = []

    mutating func record(_ change: Change) {
        changes.append(change)
        if changes.count > Self.capacity { changes.removeFirst(changes.count - Self.capacity) }
    }

    /// Takes the newest change that can be undone out of the log and returns it with its undo edit.
    mutating func popUndo() -> (edit: ConfigEdit, change: Change)? {
        guard let index = changes.lastIndex(where: { $0.undo != nil }), let edit = changes[index].undo else { return nil }
        return (edit, changes.remove(at: index))
    }
}

enum AIError: Error, Equatable {
    case unknownKey(String)
    case badValue(key: String, allowed: [String])
    case humanOnly(String)
    case emptyValue
    case usage(String)
    case unreachable(String)
    case failed(String)

    var message: String {
        switch self {
        case .unknownKey(let key):
            return "Unknown setting \"\(key)\". Settings: \(SettingKey.allCases.map(\.rawValue).joined(separator: ", "))."
        case .badValue(let key, let allowed):
            return "\"\(key)\" takes one of: \(allowed.joined(separator: ", "))."
        case .humanOnly(let key):
            let tab = SettingKey(rawValue: key)?.tab ?? "AI"
            return "\"\(key)\" keeps or sends what the user types, so only the user can turn it on. "
                + "Ask them to switch it on in Settings, tab \(tab)."
        case .emptyValue:
            return "The value is empty."
        case .usage(let text), .unreachable(let text), .failed(let text):
            return text
        }
    }
}

extension ConfigEdit {
    /// The settings after the edit, and the record of it. `change` is nil when the settings already say what
    /// the edit asks for.
    func applying(to settings: Settings, now: Date = Date()) throws -> (settings: Settings, change: Change?) {
        switch kind {
        case .set: return try applyingSet(to: settings, now: now)
        case .shorthandAdd, .shorthandRemove: return try applyingShorthand(to: settings, now: now)
        case .appRule, .appRuleRemove: return try applyingAppRule(to: settings, now: now)
        }
    }

    private func applyingSet(to settings: Settings, now: Date) throws -> (settings: Settings, change: Change?) {
        guard let setting = SettingKey(rawValue: key) else { throw AIError.unknownKey(key) }
        let wanted = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !wanted.isEmpty else { throw AIError.emptyValue }
        guard setting.choices.contains(wanted) else { throw AIError.badValue(key: key, allowed: setting.choices) }
        if setting.humanOnly, wanted == "on" { throw AIError.humanOnly(key) }
        let before = setting.value(in: settings)
        guard before != wanted else { return (settings, nil) }
        var next = settings
        setting.assign(wanted, in: &next)
        // Sharing needs collection, and the Statistics tab turns it off together with collection.
        if setting == .collectStats, wanted == "off" { next.shareStats = false }
        // Turning a privacy switch back on is not something an undo may do.
        let undo = setting.humanOnly ? nil : ConfigEdit(kind: .set, key: key, value: before)
        return (next, Change(time: now, summary: "\(key): \(before) \u{2192} \(wanted)", undo: undo))
    }

    private func applyingShorthand(to settings: Settings, now: Date) throws -> (settings: Settings, change: Change?) {
        let word = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !word.isEmpty else { throw AIError.emptyValue }
        var next = settings
        if kind == .shorthandAdd {
            guard !word.contains(where: \.isWhitespace) else {
                throw AIError.failed("A shorthand word is one word without spaces.")
            }
            guard !next.shorthand.contains(word) else { return (settings, nil) }
            next.shorthand.append(word)
            let undo = ConfigEdit(kind: .shorthandRemove, key: word)
            return (next, Change(time: now, summary: "shorthand: added \"\(word)\"", undo: undo))
        }
        guard let index = next.shorthand.firstIndex(of: word) else { return (settings, nil) }
        next.shorthand.remove(at: index)
        let undo = ConfigEdit(kind: .shorthandAdd, key: word)
        return (next, Change(time: now, summary: "shorthand: removed \"\(word)\"", undo: undo))
    }

    private func applyingAppRule(to settings: Settings, now: Date) throws -> (settings: Settings, change: Change?) {
        let id = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { throw AIError.emptyValue }
        let existing = settings.appRules.first { $0.bundleID == id }
        var next = settings
        if kind == .appRuleRemove {
            guard let existing else { return (settings, nil) }
            next.appRules.removeAll { $0.bundleID == id }
            let undo = ConfigEdit(kind: .appRule, key: id, value: existing.mode.name)
            return (next, Change(time: now, summary: "app \(id): \(existing.mode.name) \u{2192} no rule", undo: undo))
        }
        guard let mode = value.flatMap({ AppMode(name: $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }) else {
            throw AIError.badValue(key: "mode", allowed: AppMode.names)
        }
        let before = existing?.mode
        // An app without a rule already runs in the marked mode, so a rule for it would change nothing.
        guard before != mode, !(existing == nil && mode == .marked) else { return (settings, nil) }
        var rule = existing ?? AppRule(bundleID: id)
        rule.mode = mode
        if let index = next.appRules.firstIndex(where: { $0.bundleID == id }) {
            next.appRules[index] = rule
        } else {
            next.appRules.append(rule)
        }
        let undo = existing == nil
            ? ConfigEdit(kind: .appRuleRemove, key: id)
            : ConfigEdit(kind: .appRule, key: id, value: before?.name)
        return (next, Change(time: now, summary: "app \(id): \(before?.name ?? "no rule") \u{2192} \(mode.name)", undo: undo))
    }
}
