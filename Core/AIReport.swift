import Foundation

/// What `Ankey show` prints, as plain values that `JSONSerialization` writes. Every builder takes its data as
/// an argument, so the shape is decided here and the command line only reads and prints.
enum AIReport {
    static func settings(_ settings: Settings) -> [String: Any] {
        [
            "toneStyle": settings.toneStyle.rawValue,
            "restoreRaw": settings.restoreRaw,
            "abbreviation": settings.abbreviation,
            "escClears": settings.escClears,
            "suggestions": settings.suggestions,
            "learnsPhrases": settings.learnsPhrases,
            "learnsLanguage": settings.learnsLanguage,
            "keepsDiary": settings.keepsDiary,
            "collectStats": settings.collectStats,
            "shareStats": settings.shareStats,
            "onboardingSeen": settings.onboardingSeen,
            "shorthand": settings.shorthand,
            "appRules": settings.appRules.map { ["bundleID": $0.bundleID, "mode": $0.mode.name] },
        ]
    }

    /// What Ankey learned and acts on, the same lists the Settings window shows. `source` says whether the
    /// running app answered (`live`) or the files were read (`files`, up to five minutes behind).
    static func learned(
        adjust: [String: Int],
        phrases: [(prefix: String, word: String, count: Int)],
        habits: [(word: String, language: Language, samples: Int)],
        source: String
    ) -> [String: Any] {
        [
            "source": source,
            "words": adjust.sorted { $0.key < $1.key }.map { ["word": $0.key, "score": $0.value] as [String: Any] },
            "phrases": phrases.map { ["prefix": $0.prefix, "word": $0.word, "count": $0.count] as [String: Any] },
            "habits": habits.map {
                ["word": $0.word, "language": $0.language == .english ? "english" : "vietnamese", "samples": $0.samples] as [String: Any]
            },
        ]
    }

    /// What only the running app holds in memory, in one answer: the learned data and the diary. The command line
    /// asks the app for it, and builds the same answer from the files when the app is not running.
    static func snapshot(
        adjust: [String: Int],
        phrases: [(prefix: String, word: String, count: Int)],
        habits: [(word: String, language: Language, samples: Int)],
        diary: Diary?,
        limit: Int,
        source: String
    ) -> [String: Any] {
        [
            "learned": learned(adjust: adjust, phrases: phrases, habits: habits, source: source),
            "diary": AIReport.diary(diary, limit: limit),
        ]
    }

    /// The counters, oldest day first, with every event listed. No install ID: it is not data about typing.
    static func stats(_ log: StatsLog) -> [String: Any] {
        [
            "keepDays": StatsLog.keepDays,
            "days": log.ordered.map { entry -> [String: Any] in
                let counts = StatsEvent.allCases.map { ($0.rawValue, entry.counts[$0]) }
                return ["day": entry.day, "counts": Dictionary(uniqueKeysWithValues: counts)]
            },
        ]
    }

    /// The diary, or `{"enabled": false}` while it is off. `apps` sets each app's friction events against the
    /// words typed in it, most events first; `entries` are the newest `limit`.
    static func diary(_ diary: Diary?, limit: Int) -> [String: Any] {
        guard let diary else { return ["enabled": false] }
        var kinds: [String: [String: Int]] = [:]
        for entry in diary.entries { kinds[entry.app, default: [:]][entry.kind.rawValue, default: 0] += 1 }
        var words: [String: Int] = [:]
        for perApp in diary.words.values {
            for (app, count) in perApp { words[app, default: 0] += count }
        }
        let apps = Set(kinds.keys).union(words.keys).map { app -> (app: String, events: Int, words: Int, kinds: [String: Int]) in
            let byKind = kinds[app] ?? [:]
            return (app, byKind.values.reduce(0, +), words[app] ?? 0, byKind)
        }
        .sorted { left, right in
            if left.events != right.events { return left.events > right.events }
            if left.words != right.words { return left.words > right.words }
            return left.app < right.app
        }
        return [
            "enabled": true,
            "entryCount": diary.entries.count,
            "entries": diary.entries.suffix(limit).reversed().map { entry -> [String: Any] in
                ["day": entry.day, "app": entry.app, "kind": entry.kind.rawValue, "raw": entry.raw, "shown": entry.shown]
            },
            "apps": apps.map { ["app": $0.app, "events": $0.events, "words": $0.words, "byKind": $0.kinds] as [String: Any] },
        ]
    }

    /// What was changed through the command line, newest first.
    static func changes(_ log: ChangeLog) -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        return [
            "changes": log.changes.reversed().map { change -> [String: Any] in
                ["time": formatter.string(from: change.time), "summary": change.summary, "undoable": change.undo != nil]
            },
        ]
    }
}
