import Foundation

/// The phrases Ankey learned from typing: in memory for the key path, in a file for the next launch. The file
/// holds words the user typed, so only the user can read it, and it never leaves this Mac.
final class PersonalPhrasesStore: @unchecked Sendable {
    static let shared = PersonalPhrasesStore(file: PersonalPhrasesStore.defaultFile)

    private static let saveEvery = 300
    private static let saveAfter: TimeInterval = 300

    private static var defaultFile: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Ankey/personal-phrases.json")
    }

    /// Days since 1970, the clock the counts fade on.
    static var today: Int { Int(Date().timeIntervalSince1970 / 86_400) }

    private let file: URL
    private let lock = NSLock()
    private let writer = DispatchQueue(label: "dev.firegroup.ankey.personal-phrases", qos: .utility)
    private var phrases: PersonalPhrases
    private var unsaved = 0
    private var lastSave = Date()

    init(file: URL) {
        self.file = file
        phrases = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(PersonalPhrases.self, from: $0) }
            ?? PersonalPhrases()
    }

    /// Runs `body` on the phrases as they are now. They are not copied: `body` must not keep them.
    func read<T>(_ body: (PersonalPhrases) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(phrases)
    }

    func observe(context: [String], word: String, covered: Bool) {
        lock.lock()
        phrases.observe(context: context, word: word, covered: covered, today: Self.today)
        unsaved += 1
        let due = unsaved >= Self.saveEvery || Date().timeIntervalSince(lastSave) > Self.saveAfter
        lock.unlock()
        if due { flush() }
    }

    func forget(prefix: String, word: String) {
        lock.lock()
        phrases.forget(prefix: prefix, word: word)
        unsaved += 1
        lock.unlock()
        flush()
    }

    func forgetAll() {
        lock.lock()
        phrases.forgetAll()
        unsaved = 0
        lock.unlock()
        try? FileManager.default.removeItem(at: file)
    }

    func learned(limit: Int) -> [(prefix: String, word: String, count: Int)] {
        read { $0.learned(today: Self.today, limit: limit) }
    }

    /// Writes what changed since the last write, off the key path.
    func flush() {
        lock.lock()
        guard unsaved > 0 else {
            lock.unlock()
            return
        }
        let snapshot = phrases
        unsaved = 0
        lastSave = Date()
        lock.unlock()
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let file = file
        writer.async {
            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        }
    }
}
