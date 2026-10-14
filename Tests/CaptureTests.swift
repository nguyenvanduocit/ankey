import Foundation

/// Pushes every key of `keys`, returning the answer to the last one.
@discardableResult
private func type(_ keys: String, into session: inout Session) -> Push {
    var last = Push.pass
    for ch in keys { last = session.push(ch) }
    return last
}

private let context = FeedbackContext(macOS: "26.4", chip: "Apple M1", encoding: .tcvn3, mode: .direct)

private func typed(_ keys: String, _ settings: Settings = Settings(), kind: Trigger = .feedback) -> Capture {
    var capture = Capture(kind)
    for ch in keys { capture.push(ch, settings) }
    return capture
}

func checkTriggers() {
    // The code is `///` plus a name, and it can still grow while the typed text is a prefix.
    expect(Trigger.bug.code, "///bug", "bug code")
    expect(Trigger.feedback.code, "///feedback", "feedback code")
    for text in ["/", "//", "///", "///b", "///bu", "///f", "///feedbac", "///BUG", "///Feed"] {
        expect(Trigger.canStart(text), true, "\(text) can still become a trigger")
    }
    for text in ["a", "////", "///x", "///bugs", "//b", "/ /"] {
        expect(Trigger.canStart(text), false, "\(text) cannot become a trigger")
    }
    expect(Trigger(typed: "///bug"), .bug, "exact bug")
    expect(Trigger(typed: "///Feedback"), .feedback, "case does not matter")
    for text in ["///", "///fee", "///bugs", "//bug", "bug", "///bug "] {
        expect(Trigger(typed: text), nil, "\(text) is not a trigger")
    }

    // Typing the code ends in .cheat, and nothing is left composing.
    var session = Session()
    expect(type("///bu", into: &session), .consumed, "prefix is held")
    expect(session.display(Settings()), "///bu", "held text shows as typed")
    expect(session.isComposing, true, "held text counts as composing")
    expect(session.isHolding, true, "held text is holding")
    expect(session.push("g"), .cheat(.bug), "last letter activates")
    expect(session.isComposing, false, "activation leaves nothing pending")
    expect(session.display(Settings()), "", "activation leaves nothing to show")
    expect(session.push("a"), .consumed, "the next key starts a normal word")

    // Telex never touches the held text: `ee` stays `ee`.
    session = Session()
    expect(type("///fee", into: &session), .consumed, "feedback prefix is held")
    expect(session.display(Settings()), "///fee", "held text ignores Telex")
    expect(type("dback", into: &session), .cheat(.feedback), "feedback activates on its last letter")

    // A key that cannot extend the code flushes the held text. The caller commits it and pushes the key again.
    session = Session()
    expect(type("/", into: &session), .consumed, "lone slash is held")
    expect(session.push("a"), .flush, "a letter after one slash flushes")
    expect(session.finish(Settings(), expand: true), "/", "flush commits the slash")
    expect(session.isComposing, false, "flush leaves nothing pending")
    expect(session.push("a"), .consumed, "the flushed key starts a word")

    session = Session()
    type("//", into: &session)
    expect(session.push(" "), .flush, "space after two slashes flushes")
    expect(session.finish(Settings(), expand: true), "//", "two slashes commit as typed")

    session = Session()
    type("///bu", into: &session)
    expect(session.push("x"), .flush, "a wrong letter flushes")
    expect(session.finish(Settings(), expand: false), "///bu", "the prefix commits as typed")

    session = Session()
    type("///", into: &session)
    expect(session.push("/"), .flush, "a fourth slash flushes")

    // Only a word start can begin the code.
    session = Session()
    expect(session.push("a"), .consumed, "word letter")
    expect(session.push("/"), .commit, "slash after a word still ends it")
    expect(session.finish(Settings(), expand: true), "a", "the word commits before the slash")
    expect(type("//bug", into: &session), .flush, "two more slashes and a letter do not form the code")

    // Backspace and Esc.
    session = Session()
    type("//", into: &session)
    expect(session.pop(), true, "backspace drops a held slash")
    expect(session.display(Settings()), "/", "one slash left")
    expect(session.pop(), true, "backspace drops the last slash")
    expect(session.isComposing, false, "nothing left to hold")
    expect(session.pop(), false, "nothing to pop")
    type("//", into: &session)
    expect(session.finishRaw(), "//", "Esc keeps the held text as typed")
    expect(session.isComposing, false, "finishRaw leaves nothing pending")

    // A session that does not detect triggers keeps `/` as a plain boundary.
    session = Session()
    session.detectsTriggers = false
    expect(session.push("/"), .pass, "slash passes when triggers are off")
    expect(session.isComposing, false, "nothing held when triggers are off")
}

func checkCapture() {
    let plain = Settings()

    // Telex works inside the buffer.
    expect(typed("vieetj").display(plain), "vi\u{1ec7}t", "word composes")
    expect(typed("vieetj nam").display(plain), "vi\u{1ec7}t nam", "words join with spaces")
    expect(typed("xin chaof, ban!").display(plain), "xin ch\u{00e0}o, ban!", "punctuation passes")

    // Backspace pops a key, then characters of finished text.
    var capture = typed("vieetj")
    capture.backspace()
    expect(capture.display(plain), "vi\u{00ea}t", "backspace pops one raw key")
    capture = typed("ab ")
    capture.backspace()
    expect(capture.display(plain), "ab", "backspace after a space removes the space")
    capture.backspace()
    capture.backspace()
    capture.backspace()
    expect(capture.display(plain), "", "backspace on an empty buffer stays empty")
    expect(capture.isEmpty, true, "empty buffer")

    // Inside the buffer `///bug` is text, not a trigger.
    capture = typed("///bug ok")
    expect(capture.display(plain), "///bug ok", "slashes are plain text inside a capture")

    // No macro expansion: a private shortcut must not leak its text.
    var withMacro = Settings()
    withMacro.macros = [Macro(shortcut: "addr", text: "1 Secret Street")]
    capture = typed("addr ", withMacro)
    expect(capture.display(withMacro), "addr ", "macros do not expand in feedback")
    let leak = capture.submit(withMacro, context: context)
    expect(leak?.text, "addr", "the report carries the typed shortcut")

    // Control characters never enter the buffer.
    capture = typed("a\nb\tc\r")
    expect(capture.display(plain), "abc", "control characters are dropped")

    // The buffer stops at its limit.
    capture = typed(String(repeating: "1", count: Capture.limit + 5))
    expect(capture.display(plain).count, Capture.limit, "buffer stops at the limit")

    // Submit trims, returns the report once, and then waits for the result.
    capture = typed("  vieetj nam  ", kind: .bug)
    expect(capture.phase, .typing, "typing before submit")
    let report = capture.submit(plain, context: context)
    expect(report, FeedbackReport(trigger: .bug, text: "vi\u{1ec7}t nam", context: context), "report carries kind, text and context")
    expect(capture.phase, .sending, "sending after submit")
    expect(capture.submit(plain, context: context), nil, "no second submit while sending")
    capture.push("x", plain)
    capture.backspace()
    expect(capture.display(plain), "  vi\u{1ec7}t nam  ", "keys are ignored while sending")

    // A failure keeps the text, shows why, and lets the user retry.
    capture.failed("no network")
    expect(capture.phase, .failed("no network"), "failure shows its reason")
    expect(capture.display(plain), "  vi\u{1ec7}t nam  ", "failure keeps the text")
    expect(capture.submit(plain, context: context)?.text, "vi\u{1ec7}t nam", "retry sends the same text")
    capture.failed("no network")
    capture.push("!", plain)
    expect(capture.phase, .typing, "typing again clears the failure")

    // Nothing to send: an empty or blank buffer stays put.
    capture = typed("")
    expect(capture.submit(plain, context: context), nil, "empty buffer sends nothing")
    expect(capture.phase, .typing, "empty submit keeps typing")
    capture = typed("   ")
    expect(capture.submit(plain, context: context), nil, "blank buffer sends nothing")
    expect(capture.phase, .typing, "blank submit keeps typing")

}

/// The feedback event carries the typed text, macOS, chip, encoding and mode, and nothing else.
func checkFeedbackEvent() {
    let report = FeedbackReport(
        trigger: .bug, text: "g\u{00f5} \u{0111}\u{01b0}\u{1ee3}c r\u{1ed3}i m\u{1ea5}t ch\u{1eef}", context: context
    )
    let event = report.event
    expect(event.message, "ankey.feedback.bug", "message names the kind")
    expect(FeedbackReport(trigger: .feedback, text: "x", context: context).event.message, "ankey.feedback.feedback", "feedback message")
    expect(Set(event.attributes.keys), [
        "feedbackText", "macOS", "chip", "encoding", "mode",
    ], "feedback attributes are the allowlist")
    var strings: [String: String] = [:]
    for (key, value) in event.attributes {
        guard case .string(let text) = value else {
            expect(false, true, "\(key) is text")
            continue
        }
        strings[key] = text
    }
    expect(strings["feedbackText"], report.text, "text goes in feedbackText as typed")
    expect(strings["macOS"], "26.4", "macOS version")
    expect(strings["chip"], "Apple M1", "chip")
    expect(strings["encoding"], "tcvn3", "encoding is a name, not converted text")
    expect(strings["mode"], "direct", "mode")
    expect(strings.filter { $0.key != "feedbackText" }.values.contains { $0.contains(report.text) }, false, "text appears once")

    // Through the shared builder the three reserved fields stay Ankey's, and the attributes arrive as sent.
    let sent = LogEvent(message: event.message, attributes: event.attributes.merging(["service": .string("evil")]) { $1 })
    let body = String(decoding: LogIntake.body([sent]), as: UTF8.self)
    expect(body.contains("\"service\":\"ankey\""), true, "reserved service wins")
    expect(body.contains("\"feedbackText\":"), true, "text is in the body")
    expect(body.contains("bundle"), false, "no bundle id field")
}

/// A line typed the way the controller types it must come out unchanged, unless it holds a trigger.
func checkSlashTyping() {
    for line in [
        "a//b", "http://x.com/y", "// comment", "/path/to/file", "/// doc comment", "hoang/nam",
        "////bug", "a///bug", "//bug", "///bu x", "file:///tmp", "/", "//", "///", "c:/ok",
    ] {
        expect(typeLine(line), line, "slash line \(line)")
    }
    expect(typeLine("///bug"), "", "trigger leaves nothing in the document")
    expect(typeLine("x ///feedback"), "x ", "text before the trigger stays")
}
