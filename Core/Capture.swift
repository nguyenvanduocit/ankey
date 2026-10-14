import Foundation

/// What a report is about. Each kind has a cheat code of its own.
enum ReportKind: String, CaseIterable {
    case bug, feedback
}

/// A cheat code typed at the start of a word. A report code opens a report; the settings code acts at once.
enum Trigger: Equatable {
    case report(ReportKind)
    case settings

    static let prefix = "///"

    /// Every cheat code. A new one is added here and nowhere else in the matcher.
    static let all: [Trigger] = ReportKind.allCases.map(Trigger.report) + [.settings]

    /// The name typed after the slashes.
    var name: String {
        switch self {
        case .report(let kind): return kind.rawValue
        case .settings: return "ankey"
        }
    }

    var code: String { Self.prefix + name }

    /// Whether the typed text can still grow into a trigger.
    static func canStart(_ typed: String) -> Bool {
        let typed = typed.lowercased()
        return all.contains { $0.code.hasPrefix(typed) }
    }

    /// The trigger whose code is exactly the typed text.
    init?(typed: String) {
        let typed = typed.lowercased()
        guard let match = Self.all.first(where: { $0.code == typed }) else { return nil }
        self = match
    }
}

/// What a report carries besides the text the user typed. No app name, no bundle ID.
struct FeedbackContext: Equatable {
    var macOS: String
    var chip: String
    var encoding: OutputEncoding
    var mode: AppMode
}

struct FeedbackReport: Equatable {
    var kind: ReportKind
    var text: String
    var context: FeedbackContext

    /// The one log line a report becomes. The typed text sits in `feedbackText` and nowhere else.
    /// `TestMain` pins every attribute, so adding a field fails the tests until that list changes with it.
    var event: LogEvent {
        LogEvent(message: "ankey.feedback.\(kind.rawValue)", attributes: [
            "feedbackText": .string(text),
            "macOS": .string(context.macOS),
            "chip": .string(context.chip),
            "encoding": .string(context.encoding.rawValue),
            "mode": .string(context.mode.logName),
        ])
    }
}

private extension AppMode {
    var logName: String {
        switch self {
        case .off: return "off"
        case .marked: return "marked"
        case .direct: return "direct"
        }
    }
}

/// The text of a report while the user types it. Words go through the same Telex engine as normal
/// typing and are never expanded by macros, so a private shortcut cannot leak into a report.
struct Capture {
    enum Phase: Equatable {
        case typing
        case sending
        case failed(String)
    }

    static let limit = 1000

    let kind: ReportKind
    private(set) var phase = Phase.typing
    /// Finished words and the keys between them.
    private var done = ""
    private var word = Session()

    init(_ kind: ReportKind) {
        self.kind = kind
        word.detectsTriggers = false
    }

    var isEmpty: Bool { done.isEmpty && !word.isComposing }

    func display(_ settings: Settings) -> String {
        done + word.display(settings)
    }

    mutating func push(_ ch: Character, _ settings: Settings) {
        guard phase != .sending, !ch.isNewline, ch != "\t", ch != "\r",
              display(settings).count < Self.limit else { return }
        resumeTyping()
        switch word.push(ch) {
        case .consumed:
            break
        case .pass:
            done.append(ch)
        case .commit:
            done += word.finish(settings, expand: false) + String(ch)
        case .flush, .cheat:
            // Only a session that detects triggers answers this way, and this one does not.
            break
        }
    }

    mutating func backspace() {
        guard phase != .sending else { return }
        resumeTyping()
        if !word.pop(), !done.isEmpty { done.removeLast() }
    }

    /// Starts sending. Returns nil, and changes nothing but the pending word, when there is no text to
    /// send or a send is already under way.
    mutating func submit(_ settings: Settings, context: FeedbackContext) -> FeedbackReport? {
        guard phase != .sending else { return nil }
        done += word.finish(settings, expand: false)
        let text = done.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        phase = .sending
        return FeedbackReport(kind: kind, text: text, context: context)
    }

    /// The send did not go out. The text stays so the user can try again.
    mutating func failed(_ reason: String) {
        phase = .failed(reason)
    }

    private mutating func resumeTyping() {
        if case .failed = phase { phase = .typing }
    }
}
