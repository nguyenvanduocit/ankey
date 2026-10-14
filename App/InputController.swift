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
    }

    private func context(_ sender: Any!) -> Context {
        let stored = Settings.load()
        let rule = stored.rule(for: textClient(sender)?.bundleIdentifier())
        return Context(settings: stored, rule: rule)
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
                commit(sender, context(sender), expand: false)
            }
            return false
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            commit(sender, context(sender), expand: false)
            return false
        case .keyDown:
            break
        default:
            return false
        }
        if !event.modifierFlags.isDisjoint(with: [.command, .control]) {
            commit(sender, context(sender), expand: false)
            return false
        }
        if let selector = Self.commands[event.keyCode] {
            return didCommand(by: selector, client: sender)
        }
        if let text = event.characters, let scalar = text.unicodeScalars.first,
           !(0xF700...0xF8FF).contains(scalar.value) {
            return inputText(text, client: sender)
        }
        commit(sender, context(sender), expand: false)
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
            if session.display(ctx.settings) != session.raw {
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
        commit(sender, context(sender), expand: false)
        session.forgetContext()
    }

    override func menu() -> NSMenu! {
        let menu = NSMenu(title: "Ankey")
        let telex = NSMenuItem(title: "Telex", action: nil, keyEquivalent: "")
        telex.state = .on
        menu.addItem(telex)
        let vni = NSMenuItem(title: "VNI", action: #selector(showVNIJoke(_:)), keyEquivalent: "")
        vni.target = self
        menu.addItem(vni)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Cài đặt…", action: #selector(showSettings(_:)), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        if case .available(let release) = Updater.shared.state {
            let update = NSMenuItem(title: "Cập nhật lên \(release.version.text)…", action: #selector(confirmUpdate(_:)), keyEquivalent: "")
            update.target = self
            menu.addItem(update)
        }
        return menu
    }

    @objc private func confirmUpdate(_ sender: Any?) {
        guard case .available(let release) = Updater.shared.state else { return }
        NSApp.activate(ignoringOtherApps: true)
        let choice = runPixelAlert(
            title: "Ankey \(release.version.text) đã có",
            message: release.notes.isEmpty ? "Cài bản mới và khởi động lại Ankey?" : release.notes,
            buttons: ["Cập nhật", "Để sau"]
        )
        if choice == 0 {
            Updater.shared.install()
        }
    }

    @objc private func showSettings(_ sender: Any?) {
        SettingsWindowController.shared.show()
    }

    private static var jokeIndex = 0
    private static let jokes: [(title: String, body: String, button: String)] = [
        (
            "VNI à? Ở đây chỉ có Telex.",
            "Bấm bao nhiêu lần cũng vậy, VNI không có ở đây.\n\nTelex vẫn đang chạy. Gõ aa ra â, khỏi phải với tay lên hàng số.",
            "Ờ, Telex thì Telex"
        ),
        (
            "Lại VNI nữa à?",
            "Hàng số sinh ra để nhập số điện thoại, không phải để gõ tiếng Việt.\n\nThử aa, ee, oo xem, tay đỡ mỏi hơn nhiều.",
            "Thôi được, tôi sẽ thử"
        ),
        (
            "Phát hiện người dùng VNI",
            "Hệ thống đã ghi lại vụ này. Đồng nghiệp dùng Telex sẽ được thông báo.\n\n(Đùa thôi. Nhưng VNI thì vẫn không có.)",
            "Tôi xin lỗi"
        ),
        (
            "Bạn kiên trì thật.",
            "Nút này không làm gì cả, bấm thêm cũng chỉ tốn thời gian của bạn.\n\nTelex thì làm việc cả ngày không phàn nàn.",
            "Tôi chịu thua"
        ),
        (
            "a6 hay aa?",
            "Gõ a6 mất hai phím và một cú với tay. Gõ aa mất hai phím, tay vẫn ở yên.\n\nToán lớp một cũng biết chọn cái nào.",
            "Ờ thì..."
        ),
    ]

    @objc private func showVNIJoke(_ sender: Any?) {
        let joke = Self.jokes[Self.jokeIndex % Self.jokes.count]
        Self.jokeIndex += 1
        NSApp.activate(ignoringOtherApps: true)
        runPixelAlert(title: joke.title, message: joke.body, buttons: [joke.button])
    }

    private func commit(_ sender: Any!, _ ctx: Context, expand: Bool) {
        finalize(session.finish(ctx.settings, expand: expand), sender, ctx)
    }

    /// Puts the finished word in the document and leaves nothing pending.
    private func finalize(_ text: String, _ sender: Any!, _ ctx: Context) {
        if ctx.rule.insertion == .direct {
            replaceShown(with: text, sender)
            shown = ""
            return
        }
        guard !text.isEmpty, let client = textClient(sender) else { return }
        client.insertText(text, replacementRange: anywhere)
    }

    private func refresh(_ sender: Any!, _ ctx: Context) {
        let text = session.display(ctx.settings)
        if ctx.rule.insertion == .direct {
            replaceShown(with: text, sender)
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
