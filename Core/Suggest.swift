import Foundation

/// The rest of a phrase and where it came from.
struct Suggestion: Equatable {
    var text: String
    /// It came from what this user typed, not from the shared list.
    var personal: Bool
}

/// The rest of a phrase, offered when the words just typed can only go on one way.
///
/// What counts as certain comes from the phrase list (`Resources/phrases.txt`, packed by `PhraseIndex`): the
/// syllables every phrase that continues the typed words agrees on, up to the place where phrases split or one
/// ends. Words that end a phrase themselves, and no typed word at all, offer nothing.
enum Suggest {
    static let minWords = 1
    static let maxWords = 8

    /// The words to add after `words`, written in the user's tone style, or nil when nothing is certain.
    /// What the user's own text agrees on comes first, then what the shared list does.
    static func completion(
        after words: [String], style: ToneStyle, in index: PhraseIndex,
        personal: PersonalPhrases? = nil, today: Int = 0
    ) -> Suggestion? {
        if let own = personal?.certain(after: words, today: today) { return Suggestion(text: styled(own, style), personal: true) }
        return index.certain(after: words).map { Suggestion(text: styled($0, style), personal: false) }
    }

    /// Syllables compare without the tone placement: `hoà` and `hòa` are the same key.
    static func key(_ syllable: String) -> String {
        var letters = String.UnicodeScalarView()
        var tone: Unicode.Scalar?
        for scalar in syllable.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars {
            if tones.contains(scalar.value) { tone = scalar } else { letters.append(scalar) }
        }
        if let tone { letters.append(tone) }
        return String(letters)
    }

    private static let tones: Set<UInt32> = [0x0300, 0x0301, 0x0309, 0x0303, 0x0323]

    /// Types each syllable again through the engine so it takes the user's tone placement. A syllable the
    /// engine cannot type (`marx`) stays as the list has it.
    private static func styled(_ syllables: [String], _ style: ToneStyle) -> String {
        let settings = Settings(toneStyle: style, restoreRaw: false)
        return syllables.map { syllable in
            let typed = Engine.render(Engine.keys(for: syllable), settings)
            return key(typed) == key(syllable) ? typed : syllable
        }.joined(separator: " ")
    }
}
