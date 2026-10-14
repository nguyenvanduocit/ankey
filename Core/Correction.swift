import Foundation

/// The score a word should have from now on, learned from the user erasing it and typing it again.
struct Correction: Equatable {
    let word: String
    let adjust: Int
}

/// Backspace that takes a whole word out, in the composing text or in the document after a commit.
/// Typing the same keys again is a correction. Any other key forgets the word.
struct Erasure {
    /// The keys of the whole word that backspace took out.
    private(set) var keys: String?
    /// The keys the word had when the current run of backspaces began.
    private var run: String?
    /// The word just committed, while backspaces take it out of the document.
    private var committed: (keys: String, remaining: Int)?

    /// The typed keys equal the erased word, which has three letters or more: shorter words are Telex itself
    /// (`as` is `á`).
    func matches(_ raw: String) -> Bool {
        raw.count >= 3 && raw.lowercased() == keys
    }

    /// One key is about to leave the composing word.
    mutating func popping(_ raw: String) {
        if run == nil { run = raw.lowercased() }
        if raw.count == 1 { keys = run }
    }

    /// A letter joined the word. One that leaves the erased keys starts another word.
    mutating func typed(_ raw: String) {
        run = nil
        committed = nil
        if let erased = keys, !erased.hasPrefix(raw.lowercased()) { keys = nil }
    }

    /// A word ended with a boundary key. `length` is what it and the key take in the document.
    mutating func commit(_ raw: String, length: Int) {
        reset()
        committed = (raw.lowercased(), length)
    }

    /// A backspace that reached the app. Once it has taken out the committed word and its boundary key,
    /// the word counts as erased.
    mutating func deleted() {
        guard var word = committed else {
            keys = nil
            return
        }
        word.remaining -= 1
        if word.remaining > 0 {
            committed = word
        } else {
            committed = nil
            keys = word.keys
        }
    }

    mutating func reset() {
        keys = nil
        run = nil
        committed = nil
    }
}
