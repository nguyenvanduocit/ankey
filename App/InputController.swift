import Cocoa
import InputMethodKit

@objc(AnkeyInputController)
final class AnkeyInputController: IMKInputController {
    private var session = Session()
    private let anywhere = NSRange(location: NSNotFound, length: NSNotFound)
    /// Direct insertion only: the word as it sits in the document right now.
    private var shown = ""

    private struct Context {
        let settings: Settings
        let rule: AppRule
        let encoding: OutputEncoding
    }

    private func context(_ sender: Any!) -> Context {
        let stored = Settings.load()
        let rule = stored.rule(for: textClient(sender)?.bundleIdentifier())
        return Context(settings: stored, rule: rule, encoding: stored.encoding(for: rule))
    }

    // Overriding handle makes it the only entry point: IMK stops calling inputText and
    // didCommand itself. Route every key here.
    // An app selects on Cmd+A before a commit sent at that moment arrives. Cmd and Ctrl go down
    // before the letter, so the word is committed on the modifier. Asking for modifier events
    // also turns off IMK's commit-on-click, so mouse clicks commit here too.
    override func recognizedEvents(_ sender: Any!) -> Int {
        let mask: NSEvent.EventTypeMask = [.keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        return Int(mask.rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event else { return false }
        switch event.type {
        case .flagsChanged:
            if !event.modifierFlags.isDisjoint(with: [.command, .control]) {
                leaveWord(sender)
            }
            return false
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            leaveWord(sender)
            return false
        case .keyDown:
            break
        default:
            return false
        }
        if MainActor.assumeIsolated({ FeedbackFlow.shared.isActive }) { return captureKey(event, sender) }
        if !event.modifierFlags.isDisjoint(with: [.command, .control]) {
            leaveWord(sender)
            return false
        }
        if let selector = Self.commands[event.keyCode] {
            return didCommand(by: selector, client: sender)
        }
        if let text = event.characters, let scalar = text.unicodeScalars.first,
           !(0xF700...0xF8FF).contains(scalar.value) {
            return inputText(text, client: sender)
        }
        leaveWord(sender)
        return false
    }

    private static let commands: [UInt16: Selector] = [
        51: #selector(NSResponder.deleteBackward(_:)),
        36: #selector(NSResponder.insertNewline(_:)),
        76: #selector(NSResponder.insertNewline(_:)),
        48: #selector(NSResponder.insertTab(_:)),
        53: #selector(NSResponder.cancelOperation(_:)),
    ]

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        let ctx = context(sender)
        if !ctx.rule.enabled {
            commit(sender, ctx, expand: false)
            return false
        }
        guard let string, string.count == 1, let ch = string.first else {
            commit(sender, ctx, expand: false)
            return false
        }
        switch session.push(ch) {
        case .consumed:
            refresh(sender, ctx)
            return true
        case .pass:
            return false
        case .commit:
            commit(sender, ctx, expand: true)
            return false
        case .flush:
            commit(sender, ctx, expand: false)
            return inputText(string, client: sender)
        case .cheat(let trigger):
            refresh(sender, ctx)
            switch trigger {
            case .report(let kind):
                MainActor.assumeIsolated { FeedbackFlow.shared.start(kind, settings: ctx.settings) }
            case .settings:
                showSettings(nil)
            }
            return true
        }
    }

    override func didCommand(by selector: Selector!, client sender: Any!) -> Bool {
        let name = selector.map(NSStringFromSelector) ?? ""
        let ctx = context(sender)
        if name == "deleteBackward:" {
            guard session.pop() else { return false }
            refresh(sender, ctx)
            return true
        }
        if name == "cancelOperation:" {
            guard session.isComposing else { return false }
            if session.isHolding {
                commit(sender, ctx, expand: false)
                return false
            }
            if session.display(ctx.settings) != session.raw {
                StatsStore.record(.escRestoredRaw)
                finalize(session.finishRaw(), sender, ctx)
                return true
            }
            guard ctx.settings.escClears else {
                commit(sender, ctx, expand: false)
                return false
            }
            session.clear()
            refresh(sender, ctx)
            return true
        }
        let endsLine = name == "insertNewline:" || name == "insertTab:"
        if session.isComposing { commit(sender, ctx, expand: endsLine) }
        if endsLine { session.forgetContext() }
        return false
    }

    override func composedString(_ sender: Any!) -> Any! {
        let ctx = context(sender)
        return (ctx.rule.insertion == .direct ? "" : session.display(ctx.settings)) as NSString
    }

    override func commitComposition(_ sender: Any!) {
        commit(sender, context(sender), expand: false)
    }

    override func deactivateServer(_ sender: Any!) {
        endCapture()
        commit(sender, context(sender), expand: false)
        session.forgetContext()
    }

    override func menu() -> NSMenu! {
        let menu = NSMenu(title: "Ankey")
        let settings = NSMenuItem(title: "Cài đặt…", action: #selector(showSettings(_:)), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let guide = NSMenuItem(title: "Hướng dẫn…", action: #selector(showGuide(_:)), keyEquivalent: "")
        guide.target = self
        menu.addItem(guide)
        // IMK builds the menu on the main thread.
        switch MainActor.assumeIsolated({ Updater.shared.state }) {
        case .available(let release):
            let update = NSMenuItem(title: "Cập nhật lên \(release.version.text)…", action: #selector(confirmUpdate(_:)), keyEquivalent: "")
            update.target = self
            menu.addItem(update)
        case .installing:
            menu.addItem(NSMenuItem(title: "Đang cập nhật…", action: nil, keyEquivalent: ""))
        default:
            break
        }
        return menu
    }

    @MainActor @objc private func confirmUpdate(_ sender: Any?) {
        guard case .available(let release) = Updater.shared.state else { return }
        NSApp.activate(ignoringOtherApps: true)
        let choice = runPixelAlert(
            title: "Ankey \(release.version.text) đã có",
            message: release.notes.isEmpty ? "Cài bản mới và khởi động lại Ankey?" : release.notes,
            buttons: ["Cập nhật", "Để sau"]
        )
        if choice == 0 {
            Updater.shared.install { message in
                runPixelAlert(title: "Không cập nhật được", message: message, buttons: ["Đóng"])
            }
        }
    }

    @objc private func showGuide(_ sender: Any?) {
        MainActor.assumeIsolated { OnboardingWindowController.shared.show() }
    }

    /// The menu item and the `///ankey` code both open Settings here. IMK and AppKit call on the main thread.
    @objc private func showSettings(_ sender: Any?) {
        MainActor.assumeIsolated { SettingsWindowController.shared.show() }
    }

    /// The caret may now sit anywhere, so the words typed before say nothing about the next one.
    private func leaveWord(_ sender: Any!) {
        endCapture()
        commit(sender, context(sender), expand: false)
        session.forgetContext()
    }

    private func commit(_ sender: Any!, _ ctx: Context, expand: Bool) {
        let raw = session.raw
        let word = session.finish(ctx.settings, expand: expand)
        if let event = statsEvent(raw: raw, committed: word) { StatsStore.record(event) }
        finalize(word, sender, ctx)
    }

    /// Puts the finished word in the document and leaves nothing pending.
    private func finalize(_ word: String, _ sender: Any!, _ ctx: Context) {
        let text = ctx.encoding.convert(word)
        if ctx.rule.insertion == .direct {
            replaceShown(with: text, sender)
            shown = ""
            return
        }
        guard !text.isEmpty, let client = textClient(sender) else { return }
        client.insertText(text, replacementRange: anywhere)
    }

    /// The underlined word stays readable Unicode and converts when it is committed.
    /// Direct text goes into the document at once, so it converts here.
    private func refresh(_ sender: Any!, _ ctx: Context) {
        let text = session.display(ctx.settings)
        if ctx.rule.insertion == .direct {
            replaceShown(with: ctx.encoding.convert(text), sender)
            return
        }
        guard let client = textClient(sender) else { return }
        client.setMarkedText(
            text,
            selectionRange: NSRange(location: text.utf16.count, length: 0),
            replacementRange: anywhere
        )
    }

    /// The caret sits at the end of the shown word, so the word's range is the text just before it.
    private func replaceShown(with text: String, _ sender: Any!) {
        guard text != shown, let client = textClient(sender) else { return }
        let length = shown.utf16.count
        let caret = client.selectedRange().location
        if length == 0 || caret == NSNotFound || caret < length {
            if length > 0 { StatsStore.record(.directFallback) }
            client.insertText(text, replacementRange: anywhere)
        } else {
            client.insertText(text, replacementRange: NSRange(location: caret - length, length: length))
        }
        shown = text
    }

    private func textClient(_ sender: Any!) -> (any IMKTextInput)? {
        if let client = sender as? any IMKTextInput { return client }
        return client()
    }
}

// MARK: - Feedback capture

extension AnkeyInputController {
    /// A report is open: every key belongs to it, so none reaches the app.
    private func captureKey(_ event: NSEvent, _ sender: Any!) -> Bool {
        if !event.modifierFlags.isDisjoint(with: [.command, .control]) {
            leaveWord(sender)
            return false
        }
        let ctx = context(sender)
        let keyCode = event.keyCode
        let characters = event.characters
        MainActor.assumeIsolated {
            FeedbackFlow.shared.key(
                keyCode,
                characters: characters,
                settings: ctx.settings,
                context: .current(encoding: ctx.encoding, mode: ctx.rule.mode)
            )
        }
        return true
    }

    private func endCapture() {
        MainActor.assumeIsolated { FeedbackFlow.shared.cancel() }
    }
}
