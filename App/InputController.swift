import Cocoa
import InputMethodKit

@objc(AnkeyInputController)
final class AnkeyInputController: IMKInputController {
    private var session = Session()
    private let anywhere = NSRange(location: NSNotFound, length: NSNotFound)

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        let settings = Settings.load()
        if settings.isExcluded(bundleID: textClient(sender)?.bundleIdentifier()) {
            commit(sender, settings, expand: false)
            return false
        }
        guard let string, string.count == 1, let ch = string.first else {
            commit(sender, settings, expand: false)
            return false
        }
        switch session.push(ch) {
        case .consumed:
            refresh(sender, settings)
            return true
        case .pass:
            return false
        case .commit:
            commit(sender, settings, expand: true)
            return false
        }
    }

    override func didCommand(by selector: Selector!, client sender: Any!) -> Bool {
        let name = selector.map(NSStringFromSelector) ?? ""
        let settings = Settings.load()
        if name == "deleteBackward:" {
            guard session.pop() else { return false }
            refresh(sender, settings)
            return true
        }
        if name == "cancelOperation:" {
            guard session.isComposing else { return false }
            if session.display(settings) != session.raw {
                insert(session.finishRaw(), sender)
                return true
            }
            guard settings.escClears else {
                commit(sender, settings, expand: false)
                return false
            }
            session.clear()
            refresh(sender, settings)
            return true
        }
        let endsLine = name == "insertNewline:" || name == "insertTab:"
        if session.isComposing { commit(sender, settings, expand: endsLine) }
        if endsLine { session.forgetContext() }
        return false
    }

    override func composedString(_ sender: Any!) -> Any! {
        session.display(Settings.load()) as NSString
    }

    override func commitComposition(_ sender: Any!) {
        commit(sender, Settings.load(), expand: false)
    }

    override func deactivateServer(_ sender: Any!) {
        commit(sender, Settings.load(), expand: false)
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
        let alert = NSAlert()
        alert.messageText = "Ankey \(release.version.text) đã có"
        alert.informativeText = release.notes.isEmpty ? "Cài bản mới và khởi động lại Ankey?" : release.notes
        alert.addButton(withTitle: "Cập nhật")
        alert.addButton(withTitle: "Để sau")
        if alert.runModal() == .alertFirstButtonReturn {
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
        let alert = NSAlert()
        alert.messageText = joke.title
        alert.informativeText = joke.body
        alert.addButton(withTitle: joke.button)
        alert.runModal()
    }

    private func commit(_ sender: Any!, _ settings: Settings, expand: Bool) {
        insert(session.finish(settings, expand: expand), sender)
    }

    private func insert(_ text: String, _ sender: Any!) {
        guard !text.isEmpty, let client = textClient(sender) else { return }
        client.insertText(text, replacementRange: anywhere)
    }

    private func refresh(_ sender: Any!, _ settings: Settings) {
        guard let client = textClient(sender) else { return }
        let text = session.display(settings)
        if text.isEmpty {
            client.setMarkedText(
                "",
                selectionRange: NSRange(location: 0, length: 0),
                replacementRange: anywhere
            )
            return
        }
        client.setMarkedText(
            text,
            selectionRange: NSRange(location: text.utf16.count, length: 0),
            replacementRange: anywhere
        )
    }

    private func textClient(_ sender: Any!) -> (any IMKTextInput)? {
        if let client = sender as? any IMKTextInput { return client }
        return client()
    }
}
