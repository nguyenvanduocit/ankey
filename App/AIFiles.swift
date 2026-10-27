import Foundation

/// Where the AI interface keeps files, and how it writes JSON.
enum AIFiles {
    static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Ankey")
    }

    private static var changeLogFile: URL { supportDirectory.appendingPathComponent("ai-changes.json") }

    /// The command line writes the log and the Settings window reads it, in different processes.
    static func readChangeLog() -> ChangeLog {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? Data(contentsOf: changeLogFile)).flatMap { try? decoder.decode(ChangeLog.self, from: $0) } ?? ChangeLog()
    }

    static func writeChangeLog(_ log: ChangeLog) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        try encoder.encode(log).write(to: changeLogFile, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: changeLogFile.path)
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
