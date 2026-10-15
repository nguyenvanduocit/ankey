import Foundation

/// Direct insertion: the word as plain text in the document, replaced on each key. The caret sits at its end, so
/// the word is the text just before the app's selection. Text the app has selected goes with the key, the way it
/// does without an input method: an address bar shows its inline completion as selected text after the word.
/// Backspace is the app's own: it takes the selection out, else the last character, and `erased` follows. A word
/// rewritten on backspace would lose one more character in Chromium apps, which forward the key to their renderer
/// even when the input method took it, and the renderer runs its own delete. Read on Chromium main at d6acc49cd175:
/// `-[RenderWidgetHostViewCocoa keyEvent:]` forwards the event after `interpretKeyEvents:`, and Blink's
/// `kKeyboardCodeKeyDownEntries` maps `VKEY_BACK` to `DeleteBackward`. The omnibox view (`bridged_content_view.mm`)
/// stops at a key the input method took, but selects its inline completion after the word.
struct DirectWord: Equatable {
    /// The word as the user reads it. The document holds it in the app's encoding.
    private(set) var text = ""

    /// One `insertText` call on the client.
    enum Edit: Equatable {
        /// Goes in at the caret, in place of the selection.
        case insert(String)
        /// Replaces `length` UTF-16 units from `location`.
        case replace(String, location: Int, length: Int)
    }

    /// The edit that puts `text` where the word is, or nil when the document shows it already. `selection` is the
    /// app's, nil when it cannot say. `found` is false when the word is not before the selection: the text then
    /// goes in at the caret, and the old word stays.
    mutating func show(
        _ text: String, selection: @autoclosure () -> NSRange?, encoding: OutputEncoding
    ) -> (edit: Edit, found: Bool)? {
        guard text != self.text else { return nil }
        let length = encoding.convert(self.text).utf16.count
        let encoded = encoding.convert(text)
        self.text = text
        guard length > 0 else { return (.insert(encoded), true) }
        guard let selection = selection(), selection.location >= length else { return (.insert(encoded), false) }
        return (.replace(encoded, location: selection.location - length, length: length + selection.length), true)
    }

    /// The app took its selection out, or the last character of the word when nothing was selected. What is left
    /// of the word, nil when it stays whole.
    mutating func erased(selection: NSRange?, encoding: OutputEncoding) -> String? {
        if let selection, selection.length > 0 { return nil }
        text = encoding.erasingLast(text)
        return text
    }
}
