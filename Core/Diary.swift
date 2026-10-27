import Foundation

/// The ways a user takes a word back from Ankey. They are the same moments `StatsEvent` counts, and the only
/// ones a configuration change can act on: each says the engine and the user disagreed about one word.
enum DiaryKind: String, Codable, CaseIterable {
    /// Esc gave the typed keys back instead of the converted word.
    case escRestoredRaw
    /// Shift+Esc showed the typed keys of a converted word.
    case flipToEnglish
    /// Shift+Esc showed the Vietnamese reading of a word that stayed as typed.
    case flipToVietnamese
    /// Erasing a word and typing it again made Ankey learn it as English.
    case correctionToEnglish
    /// Erasing a word and typing it again made Ankey learn it as Vietnamese.
    case correctionToVietnamese
}

/// One word the user took back: the keys typed, what Ankey showed for them, and where.
struct DiaryEntry: Codable, Equatable {
    /// `2026-10-15`, the local calendar day, as `StatsLog.dayKey` writes it.
    var day: String
    var app: String
    var kind: DiaryKind
    var raw: String
    var shown: String
}

/// Where the user and the engine disagreed, for the user's AI to read when it proposes a setting. It holds
/// words the user typed and the apps they typed them in, so it is bounded, stays on this Mac, and is kept only
/// while the user has switched it on. It is not part of the statistics and nothing here reaches `StatsPayload`.
struct Diary: Codable, Equatable {
    static let maxEntries = 2000
    static let keepDays = 30
    /// A word, as typed keys or as shown, is cut to this many characters.
    static let maxWordLength = 40
    static let unknownApp = "unknown"

    /// Oldest first.
    private(set) var entries: [DiaryEntry] = []
    /// Words committed, by day and then app: what a count of entries per app is measured against.
    private(set) var words: [String: [String: Int]] = [:]

    init() {}

    mutating func record(_ kind: DiaryKind, raw: String, shown: String, app: String, on day: String) {
        entries.append(DiaryEntry(day: day, app: Self.appKey(app), kind: kind, raw: Self.cut(raw), shown: Self.cut(shown)))
        prune()
    }

    mutating func countWord(app: String, on day: String) {
        let isNewDay = words[day] == nil
        words[day, default: [:]][Self.appKey(app), default: 0] += 1
        if isNewDay { prune() }
    }

    mutating func forgetAll() {
        entries = []
        words = [:]
    }

    private static func appKey(_ app: String) -> String { app.isEmpty ? unknownApp : app }

    private static func cut(_ text: String) -> String { String(text.prefix(maxWordLength)) }

    /// Keeps the last `keepDays` days that have anything in them, like `StatsLog`, and the newest entries.
    private mutating func prune() {
        let kept = Set(Set(entries.map(\.day)).union(words.keys).sorted().suffix(Self.keepDays))
        entries.removeAll { !kept.contains($0.day) }
        words = words.filter { kept.contains($0.key) }
        if entries.count > Self.maxEntries { entries.removeFirst(entries.count - Self.maxEntries) }
    }
}
