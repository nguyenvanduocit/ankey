import Foundation

/// The diary of words the user took back: in memory for the key path, in a file for the next launch. It holds
/// words the user typed and the apps they typed them in, so only the user can read the file and it never leaves
/// this Mac. While the user has it switched off every call does nothing and nothing of it is kept.
final class DiaryStore: @unchecked Sendable {
    static let defaultFile = AIFiles.supportDirectory.appendingPathComponent("diary.json")
    static let shared = DiaryStore(file: defaultFile)

    private static let saveEvery = 300
    private static let saveAfter: TimeInterval = 300

    private let file: URL
    private let defaults: UserDefaults
    private let lock = NSLock()
    private let writer = DispatchQueue(label: "dev.firegroup.ankey.diary", qos: .utility)
    private var diary: Diary
    private var unsaved = 0
    private var lastSave = Date()
    /// Whether anything of the diary may exist, in memory or in the file, so an off switch costs no disk access
    /// on a key.
    private var mayHoldData: Bool

    init(file: URL, defaults: UserDefaults = .standard) {
        self.file = file
        self.defaults = defaults
        let stored = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(Diary.self, from: $0) }
        diary = stored ?? Diary()
        mayHoldData = stored != nil
        dropIfOff()
    }

    /// The diary file as it is, for a process that is not the input method. Nil while the switch is off. Reading
    /// changes nothing.
    static func stored(defaults: UserDefaults = .standard) -> Diary? {
        guard Settings.keepsDiary(in: defaults) else { return nil }
        return (try? Data(contentsOf: defaultFile)).flatMap { try? JSONDecoder().decode(Diary.self, from: $0) } ?? Diary()
    }

    func record(_ kind: DiaryKind, raw: String, shown: String, app: String) {
        change { $0.record(kind, raw: raw, shown: shown, app: app, on: StatsLog.dayKey(Date())) }
    }

    func countWord(app: String) {
        change { $0.countWord(app: app, on: StatsLog.dayKey(Date())) }
    }

    /// The diary as it is now, or nil while it is off.
    func snapshot() -> Diary? {
        guard Settings.keepsDiary(in: defaults) else {
            dropIfOff()
            return nil
        }
        lock.lock()
        defer { lock.unlock() }
        return diary
    }

    func forgetAll() {
        lock.lock()
        diary.forgetAll()
        unsaved = 0
        mayHoldData = false
        lock.unlock()
        let file = file
        // On the writer queue, so a write still waiting cannot bring the file back.
        writer.async { try? FileManager.default.removeItem(at: file) }
    }

    /// Writes what changed since the last write, off the key path. An off switch deletes the diary instead.
    func flush() {
        guard Settings.keepsDiary(in: defaults) else {
            dropIfOff()
            return
        }
        lock.lock()
        guard unsaved > 0 else {
            lock.unlock()
            return
        }
        let snapshot = diary
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

    private func change(_ body: (inout Diary) -> Void) {
        guard Settings.keepsDiary(in: defaults) else { return }
        lock.lock()
        body(&diary)
        mayHoldData = true
        unsaved += 1
        let due = unsaved >= Self.saveEvery || Date().timeIntervalSince(lastSave) > Self.saveAfter
        lock.unlock()
        if due { flush() }
    }

    private func dropIfOff() {
        lock.lock()
        let holds = mayHoldData
        lock.unlock()
        if holds, !Settings.keepsDiary(in: defaults) { forgetAll() }
    }
}
