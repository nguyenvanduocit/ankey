import Cocoa
import InputMethodKit

@objc(AnkeyInputController)
final class AnkeyInputController: IMKInputController {
    private var session = Session()
    private let anywhere = NSRange(location: NSNotFound, length: NSNotFound)
    /// Direct insertion only: the word as it sits in the document right now.
    private var shown = DirectWord()

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
        // Option+Backspace deletes a word in the app. Ankey cannot count it, so it ends the word like Cmd does.
        if event.keyCode == 51, event.modifierFlags.contains(.option) {
            leaveWord(sender)
            return false
        }
        if event.keyCode == Self.escapeKey, event.modifierFlags.contains(.shift), session.isComposing, !session.isHolding {
            return swapWord(sender)
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
    private static let escapeKey: UInt16 = 53

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        let ctx = context(sender)
        if !ctx.rule.enabled {
            commit(sender, ctx)
            return false
        }
        guard let string, string.count == 1, let ch = string.first else {
            commit(sender, ctx)
            return false
        }
        switch session.push(ch) {
        case .consumed:
            refresh(sender, ctx)
            return true
        case .pass:
            return false
        case .commit:
            commit(sender, ctx)
            return false
        case .flush:
            commit(sender, ctx)
            return inputText(string, client: sender)
        case .cheat(let trigger):
            switch trigger {
            case .report(let kind):
                openReport(kind, sender, ctx)
            case .settings:
                refresh(sender, ctx)
                showSettings(nil)
            }
            return true
        }
    }

    override func didCommand(by selector: Selector!, client sender: Any!) -> Bool {
        let name = selector.map(NSStringFromSelector) ?? ""
        let ctx = context(sender)
        if name == "deleteBackward:" {
            if ctx.rule.insertion == .direct {
                eraseShown(sender, ctx)
                return false
            }
            guard session.pop() else {
                session.deleted()
                return false
            }
            refresh(sender, ctx)
            return true
        }
        if name == "cancelOperation:" {
            guard session.isComposing else { return false }
            if session.isHolding {
                commit(sender, ctx)
                return false
            }
            if session.display(ctx.settings) != session.raw {
                StatsStore.record(.escRestoredRaw)
                finalize(session.finishRaw(), sender, ctx)
                return true
            }
            guard ctx.settings.escClears else {
                commit(sender, ctx)
                return false
            }
            session.clear()
            refresh(sender, ctx)
            return true
        }
        let endsLine = name == "insertNewline:" || name == "insertTab:"
        if session.isComposing { commit(sender, ctx) }
        if endsLine { session.forgetContext() }
        return false
    }

    /// Shift+Esc shows the other reading of the word being typed and keeps it open: the Vietnamese text for a
    /// word that stayed as typed, the typed keys for a converted one. Keys with one reading change nothing.
    private func swapWord(_ sender: Any!) -> Bool {
        let ctx = context(sender)
        switch session.swap(ctx.settings) {
        case .vietnamese: StatsStore.record(.flipToVietnamese)
        case .english: StatsStore.record(.flipToEnglish)
        case nil: break
        }
        refresh(sender, ctx)
        return true
    }

    override func composedString(_ sender: Any!) -> Any! {
        let ctx = context(sender)
        return (ctx.rule.insertion == .direct ? "" : session.display(ctx.settings)) as NSString
    }

    override func commitComposition(_ sender: Any!) {
        commit(sender, context(sender))
    }

    override func deactivateServer(_ sender: Any!) {
        endCapture()
        commit(sender, context(sender))
        session.forgetContext()
    }

    override func menu() -> NSMenu! {
        let menu = NSMenu(title: "Ankey")
        let settings = NSMenuItem(title: "Cài đặt…", action: #selector(showSettings(_:)), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let help = NSMenuItem(title: "Trợ giúp…", action: #selector(showHelp(_:)), keyEquivalent: "")
        help.target = self
        menu.addItem(help)
        let feedback = NSMenuItem(title: "Gửi góp ý…", action: #selector(startFeedback(_:)), keyEquivalent: "")
        feedback.target = self
        menu.addItem(feedback)
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

    @objc private func showHelp(_ sender: Any?) {
        MainActor.assumeIsolated { OnboardingWindowController.shared.show(.help) }
    }

    /// The menu item starts the same report as `///feedback`. IMK runs it on the controller of the active
    /// client. With no text field focused no key could reach the report, so none starts.
    @objc private func startFeedback(_ sender: Any?) {
        guard textClient(sender) != nil else { return }
        openReport(.feedback, sender, context(sender))
    }

    /// `///feedback`, `///bug` and the menu item all open a report here. A word still composing is typed
    /// out as it is, and a held cheat code disappears from the app.
    private func openReport(_ kind: ReportKind, _ sender: Any!, _ ctx: Context) {
        commit(sender, ctx)
        refresh(sender, ctx)
        let anchor = caretRect(sender)
        MainActor.assumeIsolated { FeedbackFlow.shared.start(kind, settings: ctx.settings, anchor: anchor) }
    }

    /// The line the caret is on, in screen coordinates. Apps that cannot say give a zero rect, and the
    /// HUD then sits at the bottom of the screen.
    private func caretRect(_ sender: Any!) -> NSRect? {
        guard let client = textClient(sender) else { return nil }
        let location = client.selectedRange().location
        var rect = NSRect.zero
        client.attributes(forCharacterIndex: location == NSNotFound ? 0 : location, lineHeightRectangle: &rect)
        return rect.height > 0 ? rect : nil
    }

    /// The menu item and the `///ankey` code both open Settings here. IMK and AppKit call on the main thread.
    @objc private func showSettings(_ sender: Any?) {
        MainActor.assumeIsolated { SettingsWindowController.shared.show() }
    }

    /// The caret may now sit anywhere, so the words typed before say nothing about the next one.
    private func leaveWord(_ sender: Any!) {
        endCapture()
        commit(sender, context(sender))
        session.forgetContext()
    }

    private func commit(_ sender: Any!, _ ctx: Context) {
        let raw = session.raw
        let word = session.finish(ctx.settings, encode: ctx.encoding.convert)
        if let correction = session.learned {
            AdjustStore.shared.set(correction.word, to: correction.adjust)
            StatsStore.record(correction.adjust > 0 ? .correctionToEnglish : .correctionToVietnamese)
        }
        if let event = statsEvent(raw: raw, committed: word) { StatsStore.record(event) }
        finalize(word, sender, ctx)
    }

    /// Puts the finished word in the document and leaves nothing pending.
    private func finalize(_ word: String, _ sender: Any!, _ ctx: Context) {
        if ctx.rule.insertion == .direct {
            replaceShown(with: word, sender, ctx)
            shown = DirectWord()
            return
        }
        let text = ctx.encoding.convert(word)
        guard !text.isEmpty, let client = textClient(sender) else { return }
        client.insertText(text, replacementRange: anywhere)
    }

    /// The underlined word stays readable Unicode and converts when it is committed.
    /// Direct text goes into the document at once, so it converts there.
    private func refresh(_ sender: Any!, _ ctx: Context) {
        let text = session.display(ctx.settings)
        if ctx.rule.insertion == .direct {
            replaceShown(with: text, sender, ctx)
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
    private func replaceShown(with text: String, _ sender: Any!, _ ctx: Context) {
        guard let client = textClient(sender) else { return }
        guard let (edit, found) = shown.show(text, selection: selection(of: client), encoding: ctx.encoding) else { return }
        if !found { StatsStore.record(.directFallback) }
        switch edit {
        case .insert(let encoded):
            client.insertText(encoded, replacementRange: anywhere)
        case .replace(let encoded, let location, let length):
            client.insertText(encoded, replacementRange: NSRange(location: location, length: length))
        }
    }

    /// Direct insertion leaves backspace to the app, which takes its selection out, else the last character of
    /// the word; the keys become the ones that type what is left. Chromium forwards the key to its renderer even
    /// when the input method took it, and the renderer runs its own delete, so a word rewritten here lost one
    /// more character.
    private func eraseShown(_ sender: Any!, _ ctx: Context) {
        let selected = textClient(sender).flatMap { self.selection(of: $0) }
        guard let left = shown.erased(selection: selected, encoding: ctx.encoding) else { return }
        if !session.erased(leaving: left) { session.deleted() }
    }

    /// The app's selection, nil when it cannot say.
    private func selection(of client: any IMKTextInput) -> NSRange? {
        let range = client.selectedRange()
        return range.location == NSNotFound ? nil : range
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
