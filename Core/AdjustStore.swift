import Foundation

/// What Ankey learned from corrections: a score per word that `Engine.englishness` adds to the word's
/// built-in band. It sits in memory for the key path and writes through to `UserDefaults`, so a key never
/// parses it. It is not part of `Settings.save`, because a settings window opened earlier would write its
/// stale copy over a later correction.
final class AdjustStore: @unchecked Sendable {
    static let shared = AdjustStore(defaults: .standard)

    /// A correction moves a word as far as the built-in bands go, no further.
    static let range = -Engine.adjustLimit...Engine.adjustLimit

    private static let key = "wordAdjust"

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var stored: [String: Int]

    init(defaults: UserDefaults) {
        self.defaults = defaults
        stored = Self.cleaned(defaults.dictionary(forKey: Self.key) as? [String: Int] ?? [:])
    }

    var words: [String: Int] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    /// Zero forgets the word.
    func set(_ word: String, to value: Int) {
        lock.lock()
        defer { lock.unlock() }
        stored = Self.cleaned(stored.merging([word: value]) { _, new in new })
        defaults.set(stored, forKey: Self.key)
    }

    /// Trimmed lowercase words, scores kept on the scale, zeros dropped. A word the built-in lists do not
    /// know as English has no English side to learn, so it is dropped too.
    private static func cleaned(_ rows: [String: Int]) -> [String: Int] {
        var result: [String: Int] = [:]
        for (word, value) in rows {
            let key = word.trimmingCharacters(in: .whitespaces).lowercased()
            let score = min(max(value, range.lowerBound), range.upperBound)
            if English.knows(key), score != 0 { result[key] = score }
        }
        return result
    }
}
