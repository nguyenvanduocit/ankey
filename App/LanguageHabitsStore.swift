import Foundation

/// The language habits Ankey learned: in memory for the key path, in a file for the next launch. Like the
/// personal phrases it holds words the user typed, so only the user can read the file.
final class LanguageHabitsStore: @unchecked Sendable {
    static let shared = LanguageHabitsStore(file: LanguageHabitsStore.defaultFile)

    private static let saveEvery = 300
    private static let saveAfter: TimeInterval = 300

    private static var defaultFile: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Ankey/language-habits.json")
    }

    private let file: URL
    private let lock = NSLock()
    private let writer = DispatchQueue(label: "dev.firegroup.ankey.language-habits", qos: .utility)
    private var habits: LanguageHabits
    private var unsaved = 0
    private var lastSave = Date()

    init(file: URL) {
        self.file = file
        habits = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(LanguageHabits.self, from: $0) }
            ?? LanguageHabits()
    }

    /// The habits as of today, for the key path. The table is shared, not copied.
    func snapshot() -> LanguageHabits {
        lock.lock()
        defer { lock.unlock() }
        var copy = habits
        copy.asOf = PersonalPhrasesStore.today
        return copy
    }

    func observe(after previous: String, language: Language, weight: Double) {
        lock.lock()
        habits.observe(after: previous, language: language, weight: weight, today: PersonalPhrasesStore.today)
        unsaved += 1
        let due = unsaved >= Self.saveEvery || Date().timeIntervalSince(lastSave) > Self.saveAfter
        lock.unlock()
        if due { flush() }
    }

    func forget(_ word: String) {
        lock.lock()
        habits.forget(word)
        unsaved += 1
        lock.unlock()
        flush()
    }

    func forgetAll() {
        lock.lock()
        habits.forgetAll()
        unsaved = 0
        lock.unlock()
        try? FileManager.default.removeItem(at: file)
    }

    func learned(limit: Int) -> [(word: String, language: Language, samples: Int)] {
        snapshot().learned(limit: limit)
    }

    /// Writes what changed since the last write, off the key path.
    func flush() {
        lock.lock()
        guard unsaved > 0 else {
            lock.unlock()
            return
        }
        let current = habits
        unsaved = 0
        lastSave = Date()
        lock.unlock()
        guard let data = try? JSONEncoder().encode(current) else { return }
        let file = file
        writer.async {
            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        }
    }
}
