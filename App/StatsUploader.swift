import Foundation

extension StatsPayload {
    /// The payload for this app build on this macOS.
    static func forThisMac(settings: Settings, log: StatsLog) -> StatsPayload {
        StatsPayload(appVersion: thisAppVersion, macOS: thisMacOS, settings: settings, log: log)
    }
}

private var thisAppVersion: String { Updater.currentVersion.text }

private var thisMacOS: String {
    let os = ProcessInfo.processInfo.operatingSystemVersion
    return "\(os.majorVersion).\(os.minorVersion)"
}

/// Asks `StatsUploader` on a timer, off the key path. The upload itself skips when it is not due.
enum StatsSchedule {
    private static let checkInterval: TimeInterval = 3600
    private static let launchDelay: Duration = .seconds(60)

    @MainActor static func start(sender: any LogSender = DatadogLogSender.shared) {
        Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { _ in
            Task { await uploadIfDue(sender) }
        }
        Task {
            try? await Task.sleep(for: launchDelay)
            await uploadIfDue(sender)
        }
    }

    private static func uploadIfDue(_ sender: any LogSender) async {
        await StatsUploader.uploadIfDue(sender: sender, appVersion: thisAppVersion, macOS: thisMacOS)
    }
}
