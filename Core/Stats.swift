import Foundation

/// Something that happened, counted and never described. No event carries text, a key or an app.
enum StatsEvent: String, CaseIterable {
    /// A word committed and the engine changed it (`vieetj` became `việt`).
    case wordChanged
    /// A word committed exactly as typed.
    case wordKept
    /// Esc gave the typed keys back instead of the converted word.
    case escRestoredRaw
    /// Direct insertion could not find its word and inserted at the wrong range.
    case directFallback
    /// Erasing a word and typing it again made Ankey learn it as English.
    case correctionToEnglish
    /// Erasing a word and typing it again made Ankey learn it as Vietnamese.
    case correctionToVietnamese
    /// Shift+Esc showed the typed keys of a converted word.
    case flipToEnglish
    /// Shift+Esc showed the Vietnamese reading of a word that stayed as typed.
    case flipToVietnamese
    /// What the user usually writes after the word before made a word that could be either show as typed.
    case habitToEnglish
    /// What the user usually writes after the word before made a word that could be either convert.
    case habitToVietnamese
    /// The shared phrase list offered the rest of a phrase. Shown less accepted less dismissed is how often the
    /// user typed on past it.
    case sharedSuggestionShown
    /// Tab put a suggestion from the shared list in the document.
    case sharedSuggestionAccepted
    /// Esc or Backspace took a suggestion from the shared list away.
    case sharedSuggestionDismissed
    /// What the user typed before offered the rest of a phrase.
    case personalSuggestionShown
    /// Tab put a suggestion learned from the user in the document.
    case personalSuggestionAccepted
    /// Esc or Backspace took a suggestion learned from the user away.
    case personalSuggestionDismissed
}

/// The counters of one day.
struct StatsDay: Equatable {
    private(set) var counts: [StatsEvent: Int] = [:]

    subscript(event: StatsEvent) -> Int { counts[event] ?? 0 }

    mutating func add(_ event: StatsEvent) {
        counts[event, default: 0] += 1
    }

    init() {}

    /// A counter that is missing, negative or unknown is dropped.
    init(stored row: [String: Int]) {
        for event in StatsEvent.allCases {
            if let count = row[event.rawValue], count > 0 { counts[event] = count }
        }
    }

    var stored: [String: Int] {
        Dictionary(uniqueKeysWithValues: counts.map { ($0.key.rawValue, $0.value) })
    }
}

/// The counters kept on this machine, by day.
struct StatsLog: Equatable {
    static let keepDays = 30

    fileprivate(set) var days: [String: StatsDay] = [:]

    init() {}

    init(stored rows: [String: [String: Int]]) {
        for (day, row) in rows where Self.isDayKey(day) {
            days[day] = StatsDay(stored: row)
        }
        prune()
    }

    var stored: [String: [String: Int]] {
        days.mapValues(\.stored)
    }

    mutating func record(_ event: StatsEvent, on day: String) {
        days[day, default: StatsDay()].add(event)
        prune()
    }

    /// The days oldest first, so the shown data reads in time order.
    var ordered: [(day: String, counts: StatsDay)] {
        days.keys.sorted().map { ($0, days[$0] ?? StatsDay()) }
    }

    /// `2026-10-15`: the local calendar day.
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func isDayKey(_ text: String) -> Bool {
        let digits = text.split(separator: "-", omittingEmptySubsequences: false)
        return digits.count == 3 && digits.map(\.count) == [4, 2, 2] && digits.allSatisfy { $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }
    }

    private mutating func prune() {
        for day in days.keys.sorted().dropLast(Self.keepDays) { days[day] = nil }
    }
}

/// What a committed word says about the engine: changed or kept. An empty word says nothing.
func statsEvent(raw: String, committed: String) -> StatsEvent? {
    raw.isEmpty ? nil : (committed == raw ? .wordKept : .wordChanged)
}

/// The statistics as log events: one per day. Every attribute is listed in `TestMain`'s allowlist, so
/// adding a field fails the tests until that list changes with it.
struct StatsPayload {
    var appVersion: String
    var macOS: String
    var toneStyle: ToneStyle
    var appRuleCount: Int
    var log: StatsLog

    init(appVersion: String, macOS: String, settings: Settings, log: StatsLog) {
        self.appVersion = appVersion
        self.macOS = macOS
        toneStyle = settings.toneStyle
        appRuleCount = settings.appRules.count
        self.log = log
    }

    /// `installID` joins the events only once the user shares them.
    func events(installID: String?) -> [LogEvent] {
        log.ordered.map { entry in
            var attributes: [String: LogAttribute] = [
                "appVersion": .string(appVersion),
                "macOS": .string(macOS),
                "toneStyle": .string(toneStyle.rawValue),
                "appRuleCount": .int(appRuleCount),
                "day": .string(entry.day),
            ]
            for event in StatsEvent.allCases { attributes[event.rawValue] = .int(entry.counts[event]) }
            if let installID { attributes["installID"] = .string(installID) }
            return LogEvent(message: "ankey.stats.day", attributes: attributes)
        }
    }
}

extension StatsLog {
    /// The finished days not sent yet. Today is still counting, so it waits.
    func pending(uploadedThrough: String?, today: String) -> StatsLog {
        var result = StatsLog()
        for (day, counts) in days where day < today && day > (uploadedThrough ?? "") {
            result.days[day] = counts
        }
        return result
    }
}

/// Where the upload stands, so it runs at most once a calendar day.
struct StatsUploadState: Equatable {
    var lastAttemptDay: String?
    var uploadedThrough: String?

    func isDue(on today: String) -> Bool { lastAttemptDay != today }
}

/// Reads and writes the log in `UserDefaults`. Every call does nothing while the setting is off.
enum StatsStore {
    private static let key = "stats"

    static func record(_ event: StatsEvent, now: Date = Date(), defaults: UserDefaults = .standard) {
        guard Settings.collectsStats(in: defaults) else { return }
        var log = load(from: defaults)
        log.record(event, on: StatsLog.dayKey(now))
        defaults.set(log.stored, forKey: key)
    }

    static func load(from defaults: UserDefaults = .standard) -> StatsLog {
        StatsLog(stored: defaults.dictionary(forKey: key) as? [String: [String: Int]] ?? [:])
    }

    static func clear(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }

    // MARK: Sharing

    private static let installIDKey = "statsInstallID"
    private static let lastAttemptKey = "statsLastAttemptDay"
    private static let uploadedThroughKey = "statsUploadedThrough"

    /// A random ID that tells one install's days apart. It exists only while the user shares.
    static func installID(from defaults: UserDefaults = .standard) -> String {
        if let id = defaults.string(forKey: installIDKey) { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: installIDKey)
        return id
    }

    static func uploadState(from defaults: UserDefaults = .standard) -> StatsUploadState {
        StatsUploadState(
            lastAttemptDay: defaults.string(forKey: lastAttemptKey),
            uploadedThrough: defaults.string(forKey: uploadedThroughKey)
        )
    }

    static func save(_ state: StatsUploadState, to defaults: UserDefaults = .standard) {
        defaults.set(state.lastAttemptDay, forKey: lastAttemptKey)
        defaults.set(state.uploadedThrough, forKey: uploadedThroughKey)
    }

    /// Sharing off forgets the ID and the upload position. Turning it on again starts a new identity.
    static func forgetSharing(from defaults: UserDefaults = .standard) {
        for key in [installIDKey, lastAttemptKey, uploadedThroughKey] { defaults.removeObject(forKey: key) }
    }
}

/// Sends the finished days once per calendar day. A failure is silent: the days stay pending and the
/// next day tries again. The caller decides when to ask, and never asks from a key.
enum StatsUploader {
    static func uploadIfDue(
        sender: any LogSender,
        appVersion: String,
        macOS: String,
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) async {
        let settings = Settings.load(from: defaults)
        guard settings.collectStats, settings.shareStats else { return }
        let today = StatsLog.dayKey(now)
        var state = StatsStore.uploadState(from: defaults)
        guard state.isDue(on: today) else { return }
        state.lastAttemptDay = today
        StatsStore.save(state, to: defaults)

        let pending = StatsStore.load(from: defaults).pending(uploadedThrough: state.uploadedThrough, today: today)
        guard let last = pending.ordered.last?.day else { return }
        let payload = StatsPayload(appVersion: appVersion, macOS: macOS, settings: settings, log: pending)
        do {
            try await sender.send(payload.events(installID: StatsStore.installID(from: defaults)))
        } catch {
            return
        }
        // The user may have turned sharing off while the request was in flight.
        guard Settings.load(from: defaults).shareStats else { return }
        state.uploadedThrough = last
        StatsStore.save(state, to: defaults)
    }
}
