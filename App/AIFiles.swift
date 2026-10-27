import Foundation

/// Where the AI interface keeps files, and how it writes JSON.
enum AIFiles {
    static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Ankey")
    }

    private static func changeLogFile(in directory: URL) -> URL { directory.appendingPathComponent("ai-changes.json") }

    /// The command line writes the log and the Settings window reads it, in different processes.
    static func readChangeLog(in directory: URL = supportDirectory) -> ChangeLog {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? Data(contentsOf: changeLogFile(in: directory))).flatMap { try? decoder.decode(ChangeLog.self, from: $0) } ?? ChangeLog()
    }

    private static func writeChangeLog(_ log: ChangeLog, in directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let file = changeLogFile(in: directory)
        try encoder.encode(log).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }

    /// Reads the log, lets `body` change it and writes it back, all under a file lock: two command lines at once
    /// (an AI may run two commands in one turn) would otherwise read the same log and one change would be lost.
    /// `body` throwing leaves the log as it was.
    @discardableResult
    static func updateChangeLog<Result>(in directory: URL = supportDirectory, _ body: (inout ChangeLog) throws -> Result) throws -> Result {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let lock = open(directory.appendingPathComponent("ai-changes.lock").path, O_CREAT | O_RDWR, 0o600)
        guard lock >= 0 else { throw CocoaError(.fileWriteUnknown) }
        // Closing the descriptor releases the lock.
        defer { close(lock) }
        guard flock(lock, LOCK_EX) == 0 else { throw CocoaError(.fileLocking) }
        var log = readChangeLog(in: directory)
        let result = try body(&log)
        try writeChangeLog(log, in: directory)
        return result
    }

    // MARK: Snapshots

    /// What the running app holds (learned data, the diary) reaches the command line as a file. A reply travels on
    /// a channel every process of the login session can observe, so typed words stay out of it.
    static func snapshotFile(id: String, in directory: URL = supportDirectory) -> URL {
        directory.appendingPathComponent("snapshot-\(id).json")
    }

    /// Created with the mode already set, so there is no moment when another user could read it.
    static func writeSnapshot(_ text: String, id: String, in directory: URL = supportDirectory) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = snapshotFile(id: id, in: directory)
        guard FileManager.default.createFile(atPath: file.path, contents: Data(text.utf8), attributes: [.posixPermissions: 0o600]) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    /// The snapshot for `id`, read and deleted. Nil when there is none.
    static func takeSnapshot(id: String, in directory: URL = supportDirectory) -> Data? {
        let file = snapshotFile(id: id, in: directory)
        defer { try? FileManager.default.removeItem(at: file) }
        return try? Data(contentsOf: file)
    }

    /// A snapshot the command line never took (it was killed) is typed words left on disk: delete the old ones.
    static func sweepSnapshots(olderThan age: TimeInterval = 60, in directory: URL = supportDirectory, now: Date = Date()) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for file in files where file.lastPathComponent.hasPrefix("snapshot-") && file.pathExtension == "json" {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(modified) > age { try? FileManager.default.removeItem(at: file) }
        }
    }
}

enum AIJSON {
    /// Sorted keys, so the same data prints the same text.
    static func text(_ object: Any, pretty: Bool = true) -> String {
        let options: JSONSerialization.WritingOptions = pretty ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] : [.sortedKeys, .withoutEscapingSlashes]
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: options) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}
