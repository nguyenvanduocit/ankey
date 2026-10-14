import Foundation

/// The one sender every feature uses to reach Datadog Logs. Callers build `LogEvent`s and call `send`.
/// Datadog receives the sender's IP address and the user agent below with every request.
struct DatadogLogSender: LogSender {
    enum Failure: Error {
        case notConfigured
        case rejected(status: Int)
    }

    static let shared = DatadogLogSender(host: DatadogConfig.intakeHost, clientToken: DatadogConfig.clientToken)

    private static let session = URLSession(configuration: .ephemeral)

    let host: String
    let clientToken: String

    var isConfigured: Bool { !clientToken.isEmpty }

    func send(_ events: [LogEvent]) async throws {
        guard isConfigured else { throw Failure.notConfigured }
        guard !events.isEmpty else { return }
        let request = LogIntake.request(events, host: host, clientToken: clientToken, userAgent: Self.userAgent)
        let (_, response) = try await Self.session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw Failure.rejected(status: status) }
    }

    static var userAgent: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "Ankey/\(Updater.currentVersion.text) (macOS \(os.majorVersion).\(os.minorVersion))"
    }
}
