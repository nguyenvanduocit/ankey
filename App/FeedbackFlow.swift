import Foundation

/// A report from the cheat code to the send result: the buffer, the HUD, and the one send.
/// One report is open at a time, so this is a single object and not a field of each input controller.
@MainActor
final class FeedbackFlow {
    static let shared = FeedbackFlow(sender: .shared)

    private let sender: DatadogLogSender
    private let hud: FeedbackHUD
    private var capture: Capture?

    init(sender: DatadogLogSender, hud: FeedbackHUD = .shared) {
        self.sender = sender
        self.hud = hud
        hud.onClose = { [weak self] in self?.dismiss() }
    }

    /// While a report is open it takes every key.
    var isActive: Bool { capture != nil }

    /// The cheat code was typed. Without a place to send a report the user hears so at once,
    /// instead of writing one that cannot go anywhere.
    func start(_ kind: ReportKind, settings: Settings) {
        guard sender.isConfigured else {
            hud.show(.unavailable)
            return
        }
        capture = Capture(kind)
        render(settings)
    }

    /// One key while a report is open. The app never sees it.
    func key(_ keyCode: UInt16, characters: String?, settings: Settings, context: @autoclosure () -> FeedbackContext) {
        switch keyCode {
        case 36, 76:
            submit(settings, context())
        case 53:
            if capture?.phase != .sending { cancel() }
        case 51:
            capture?.backspace()
        default:
            // The 0xF700 block holds the arrow and function keys.
            if let characters, let scalar = characters.unicodeScalars.first, !(0xF700...0xF8FF).contains(scalar.value) {
                for ch in characters { capture?.push(ch, settings) }
            }
        }
        render(settings)
    }

    /// The X button: the report and the HUD both go, whatever the HUD shows. A send already under way
    /// still ends in a notice.
    func dismiss() {
        capture = nil
        hud.hide()
    }

    /// Throws the report away. A send already under way still ends in a notice.
    func cancel() {
        guard capture != nil else { return }
        capture = nil
        hud.hide()
    }

    private func submit(_ settings: Settings, _ context: FeedbackContext) {
        guard var active = capture else { return }
        let report = active.submit(settings, context: context)
        capture = active
        guard let report else { return }
        Task {
            var failure: String?
            do {
                try await sender.send([report.event])
            } catch {
                failure = feedbackFailureMessage(error)
            }
            finished(failure: failure)
        }
    }

    /// A send ends in one of three places: the capture is still waiting on it, the user cancelled
    /// the capture meanwhile, or a newer capture has started and keeps the HUD.
    private func finished(failure: String?) {
        switch capture?.phase {
        case .sending?:
            if let failure {
                capture?.failed(failure)
                render(Settings.load())
            } else {
                capture = nil
                hud.show(.sent)
            }
        case nil:
            hud.show(failure.map(HUDState.notSent) ?? .sent)
        default:
            break
        }
    }

    private func render(_ settings: Settings) {
        guard let capture else { return }
        hud.show(.capture(capture.kind, text: capture.display(settings), phase: capture.phase))
    }
}
