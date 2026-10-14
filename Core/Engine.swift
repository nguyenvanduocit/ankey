import Foundation

enum Push: Equatable {
    /// Key joined the current syllable. Show it as marked text.
    case consumed
    /// Nothing is being composed. The app should receive the key.
    case pass
    /// Finish the syllable, then let the key through (space, punctuation).
    case commit
    /// The held start of a cheat code cannot grow with this key. Commit the held text,
    /// then push the same key again.
    case flush
    /// The held text is a complete cheat code. It is gone from the session; the caller clears what it showed.
    case cheat(Trigger)
}

struct Session {
    private(set) var raw = ""
    /// A `/` at the start of a word is held as typed while it can still become a cheat code (`///bug`).
    /// It is never run through Telex.
    private var held = ""
    /// Capture sessions turn this off: inside a report `///bug` is plain text.
    var detectsTriggers = true
    /// The language of the last finished word that showed one. Ambiguous words follow it.
    private var previous: Language?
    private var endsSentence = false
    /// The boundary key that ended the word, until `finish` reads it.
    private var boundary: Character?
    /// The last finished word showed Vietnamese. Only a dot right after it reads as prose.
    private var afterVietnamese = false
    /// The word follows code punctuation with no space (`my_var`), so it is code and stays as typed.
    private var glued = false
    private var erasure = Erasure()
    /// The user asked for the other reading of this word. Any change to the keys takes it back.
    private var swapped = false
    /// What the last finished word learned: it was erased and typed again, and it showed the other language.
    private(set) var learned: Correction?

    /// Keys that join two words into one code token. Only characters that never open a phrase in
    /// prose are here: `/` (và/hoặc), brackets (`[hoàn thành]`) and `*` (bold) also appear in Vietnamese.
    private static let glue: Set<Character> = ["_", "@", "\\", "=", "|", "&", "$", "^", "~"]

    var isComposing: Bool { !raw.isEmpty || isHolding }

    /// The pending text is the start of a cheat code, not a word.
    var isHolding: Bool { !held.isEmpty }

    func display(_ settings: Settings) -> String {
        isHolding ? held : decide(settings).verdict.text
    }

    /// What the word shows and learns. A swapped word shows its other reading and learns nothing: the swap
    /// is a choice for this word only.
    private func decide(_ settings: Settings) -> (verdict: Engine.Verdict, correction: Correction?) {
        let (verdict, correction) = read(settings)
        guard swapped else { return (verdict, correction) }
        return (Engine.opposite(raw, settings, of: verdict), nil)
    }

    /// The verdict for the typed keys. A word that is erased and typed again shows the other language at once,
    /// and the correction is what it learns when it is committed.
    private func read(_ settings: Settings) -> (verdict: Engine.Verdict, correction: Correction?) {
        let verdict = Engine.analyze(raw, settings, after: previous, glued: glued)
        guard erasure.matches(raw), verdict.contested else { return (verdict, nil) }
        let correction = Correction(word: raw.lowercased(), adjust: verdict.language == .english ? -Engine.adjustLimit : Engine.adjustLimit)
        var flipped = settings
        flipped.adjust[correction.word] = correction.adjust
        return (Engine.analyze(raw, flipped, after: previous, glued: glued), correction)
    }

    /// A dot glues words in `foo.bar` and `README.md`, not after Vietnamese (`ừm...tôi`).
    private static func glues(_ ch: Character, afterVietnamese: Bool) -> Bool {
        glue.contains(ch) || (ch == "." && !afterVietnamese)
    }

    /// Commits the word and remembers its language for the next one. `encode` turns the text into what the
    /// document will hold, so the backspaces that delete it can be counted.
    mutating func finish(_ settings: Settings, encode: (String) -> String = { $0 }) -> String {
        let (verdict, correction) = decide(settings)
        let text = isHolding ? held : verdict.text
        let language = verdict.language
        let keys = raw
        let endedByKey = boundary != nil
        glued = boundary.map { Self.glues($0, afterVietnamese: language == .vietnamese) } ?? false
        afterVietnamese = language == .vietnamese
        boundary = nil
        if endsSentence {
            previous = nil
        } else if let language {
            previous = language
        }
        endsSentence = false
        raw = ""
        held = ""
        swapped = false
        learned = correction
        erasure.reset()
        if endedByKey, !keys.isEmpty { erasure.commit(keys, length: encode(text).count + 1) }
        return text
    }

    /// The typed keys as they are. The word counts as English from here on.
    mutating func finishRaw() -> String {
        let text = isHolding ? held : raw
        raw = ""
        held = ""
        swapped = false
        previous = .english
        endsSentence = false
        glued = false
        afterVietnamese = false
        boundary = nil
        learned = nil
        erasure.reset()
        return text
    }

    mutating func forgetContext() {
        previous = nil
        glued = false
        afterVietnamese = false
        erasure.reset()
    }

    mutating func push(_ ch: Character) -> Push {
        if isHolding {
            erasure.reset()
            return pushHeld(ch)
        }
        if detectsTriggers, raw.isEmpty, ch == "/" {
            erasure.reset()
            held = "/"
            return .consumed
        }
        if Engine.isComposing(ch) {
            raw.append(ch)
            swapped = false
            erasure.typed(raw)
            return .consumed
        }
        let sentenceEnd = ".!?".contains(ch)
        if raw.isEmpty {
            erasure.reset()
            if sentenceEnd { previous = nil }
            glued = Self.glues(ch, afterVietnamese: afterVietnamese)
            if ch != "." { afterVietnamese = false }
            return .pass
        }
        endsSentence = sentenceEnd
        boundary = ch
        return .commit
    }

    private mutating func pushHeld(_ ch: Character) -> Push {
        let typed = held + String(ch)
        guard Trigger.canStart(typed) else { return .flush }
        if let trigger = Trigger(typed: typed) {
            held = ""
            return .cheat(trigger)
        }
        held = typed
        return .consumed
    }

    mutating func pop() -> Bool {
        if isHolding {
            held.removeLast()
            return true
        }
        guard !raw.isEmpty else { return false }
        erasure.popping(raw)
        raw.removeLast()
        swapped = false
        return true
    }

    /// A backspace that went to the app because no word was composing.
    mutating func deleted() {
        erasure.deleted()
    }

    /// Shows the other reading of the word being typed: the Telex text for keys shown as typed, the typed keys
    /// for a converted word. Returns the language now shown, or nil when the keys have no other reading
    /// (`hello`) or nothing is being typed.
    mutating func swap(_ settings: Settings) -> Language? {
        guard !raw.isEmpty, !isHolding else { return nil }
        let before = display(settings)
        swapped.toggle()
        if display(settings) == before {
            swapped.toggle()
            return nil
        }
        return decide(settings).verdict.language
    }

    mutating func clear() {
        raw = ""
        held = ""
        swapped = false
        learned = nil
        erasure.reset()
    }
}

enum Language {
    case vietnamese
    case english
}

enum Engine {
    /// A word at this score or above stays as typed.
    static let englishThreshold = 2

    /// A learned score moves a word as far as the built-in bands go. A correction sets the word to one end,
    /// so the word is English (or Vietnamese) after any word.
    static let adjustLimit = 2

    static func isComposing(_ ch: Character) -> Bool {
        ch.isASCII && ch.isLetter
    }

    static func render(
        _ raw: String, _ settings: Settings = Settings(), after previous: Language? = nil, glued: Bool = false
    ) -> String {
        analyze(raw, settings, after: previous, glued: glued).text
    }

    /// What Telex makes of the keys: the atoms, the tone, the converted text and the keys as typed.
    private static func telex(_ raw: String, _ settings: Settings) -> (atoms: [Atom], tone: Tone, out: String, literal: String) {
        var atoms: [Atom] = []
        var tone = Tone.none
        var toneFrom: Character?
        var markFrom: Character?
        var escaped: Character?
        var literal = ""
        for ch in raw {
            let upper = ch.isLetter && ch.isUppercase
            let key = Character(String(ch).lowercased())
            let undidMark = consumeTelex(&atoms, &tone, &toneFrom, &markFrom, &escaped, key: key, upper: upper)
            // The first press of an undone mark already sits in the literal text.
            if !undidMark { literal.append(ch) }
        }
        atoms = normalizeHorn(atoms)
        return (atoms, tone, compose(atoms, tone: tone, style: settings.toneStyle), literal)
    }

    /// The text a word shows and the language it reveals. `language` is nil when the word reads the same in
    /// both. `contested` means the word had two real texts and the lists know it as English, so a correction
    /// can move it: the typed keys are a choice only then, which keeps `banj` and `tooi` from ever turning English.
    struct Verdict {
        var text: String
        var language: Language?
        var contested = false
    }

    /// `previous` is the language of the word before it.
    static func analyze(
        _ raw: String, _ settings: Settings, after previous: Language?, glued: Bool = false
    ) -> Verdict {
        let (atoms, tone, out, literal) = telex(raw, settings)
        let language: Language? = out == literal ? nil : .vietnamese
        guard settings.restoreRaw else { return Verdict(text: out, language: language) }
        if glued { return Verdict(text: literal, language: .english) }
        let word = raw.lowercased()
        // How English the word looks: its built-in band, one more right after an English word, plus what Ankey
        // learned from corrections. The syllable check runs only for the few words the lists know.
        let band = English.band[word]
        let score = (band ?? 0) + (previous == .english ? 1 : 0) + (settings.adjust[word] ?? 0)
        let listed = band != nil && out != literal
        if score >= englishThreshold {
            let contested = listed && isSyllable(atoms, tone, out, settings)
            return Verdict(text: literal, language: .english, contested: contested)
        }
        guard isSyllable(atoms, tone, out, settings) else { return Verdict(text: literal, language: .english) }
        return Verdict(text: out, language: language, contested: listed)
    }

    /// The other reading of the keys: the typed keys when the verdict shows the Telex text, the Telex text when
    /// it shows the typed keys. Keys Telex leaves alone have one reading, so the verdict stays.
    static func opposite(_ raw: String, _ settings: Settings, of verdict: Verdict) -> Verdict {
        let (_, _, out, literal) = telex(raw, settings)
        guard out != literal else { return verdict }
        return verdict.text == out ? Verdict(text: literal, language: .english) : Verdict(text: out, language: .vietnamese)
    }

    /// Telex made a syllable the engine accepts, or one of the user's abbreviations.
    private static func isSyllable(_ atoms: [Atom], _ tone: Tone, _ out: String, _ settings: Settings) -> Bool {
        isRealSyllable(atoms, tone: tone, style: settings.toneStyle)
            || (settings.abbreviation && settings.shorthand.contains(out.lowercased()))
    }
}

// MARK: - Atoms

private enum Hat {
    case none
    case circumflex
    case breve
    case horn
}

enum Tone: Int {
    case none = 0
    case sac, huyen, hoi, nga, nang
}

private struct Atom {
    var base: Character
    var upper: Bool
    var hat: Hat = .none
    var stroke = false
    var markKey: Character?

    var isVowel: Bool { "aeiouy".contains(base) }

    /// Vowel identity used for tone placement, without the tone itself.
    var nucleus: String {
        switch (base, hat) {
        case ("a", .circumflex): return "â"
        case ("a", .breve): return "ă"
        case ("e", .circumflex): return "ê"
        case ("o", .circumflex): return "ô"
        case ("o", .horn): return "ơ"
        case ("u", .horn): return "ư"
        default: return String(base)
        }
    }
}

private let telexTone: [Character: Tone] = [
    "s": .sac, "f": .huyen, "r": .hoi, "x": .nga, "j": .nang,
]

// MARK: - Telex consume

/// Returns true when the key undid a mark (`noww` → `now`).
/// `markFrom` is the mark key typed right before this key, the only key that can undo it.
private func consumeTelex(
    _ atoms: inout [Atom],
    _ tone: inout Tone,
    _ toneFrom: inout Character?,
    _ markFrom: inout Character?,
    _ escaped: inout Character?,
    key: Character,
    upper: Bool
) -> Bool {
    let afterTone = toneFrom != nil
    let repeated = markFrom == key
    markFrom = nil
    if key == escaped {
        atoms.append(Atom(base: key, upper: upper))
        escaped = nil
        toneFrom = nil
        return false
    }
    escaped = nil
    if key == "z" {
        toneFrom = nil
        if tone != .none {
            tone = .none
        } else {
            atoms.append(Atom(base: key, upper: upper))
        }
        return false
    }
    if let next = telexTone[key] {
        if hasVowel(atoms) {
            // A second tap undoes the tone only when it is the very next key.
            if tone == next, toneFrom == key {
                tone = .none
                toneFrom = nil
                escaped = key
                atoms.append(Atom(base: key, upper: upper))
            } else {
                tone = next
                toneFrom = key
            }
        } else {
            toneFrom = nil
            atoms.append(Atom(base: key, upper: upper))
        }
        return false
    }
    toneFrom = nil
    if let intent = telexIntent(key) {
        switch applyMark(&atoms, key: key, upper: upper, repeated: repeated, afterTone: afterTone, intent) {
        case .applied:
            markFrom = key
            return false
        case .undone: return true
        case .none: break
        }
    }
    atoms.append(Atom(base: key, upper: upper))
    return false
}

private func hasVowel(_ atoms: [Atom]) -> Bool {
    atoms.contains(where: \.isVowel)
}

private enum MarkResult {
    case none
    case applied
    case undone
}

private enum Intent {
    /// The letter the key repeats (`aa`).
    case circumflex(Character)
    case hornOrBreve
    case stroke
}

private func telexIntent(_ key: Character) -> Intent? {
    switch key {
    case "a", "e", "o": return .circumflex(key)
    case "w": return .hornOrBreve
    case "d": return .stroke
    default: return nil
    }
}

/// A horn or breve finds its vowel in the last vowel cluster, wherever the key is typed after it.
/// With no open vowel left, repeating the key undoes the mark and keeps the key as a literal letter.
/// A circumflex key marks and undoes only the vowels right before it. Only the very next key
/// undoes a mark, so a tone key between two e's keeps `reference` whole.
private func applyMark(
    _ atoms: inout [Atom], key: Character, upper: Bool, repeated: Bool, afterTone: Bool, _ intent: Intent
) -> MarkResult {
    if case .stroke = intent { return applyStroke(&atoms, key: key, upper: upper) }
    let cluster = vowelRange(atoms)
    guard !cluster.isEmpty else { return .none }
    if let (i, hat) = markTarget(atoms, cluster, afterTone: afterTone, intent) {
        atoms[i].hat = hat
        atoms[i].markKey = key
        return .applied
    }
    let marked = cluster.filter { atoms[$0].markKey == key }
    guard repeated, !marked.isEmpty else { return .none }
    // The repeat that applies a circumflex also undoes it, and only right after the vowels.
    if case .circumflex = intent, cluster.upperBound != atoms.count { return .none }
    for i in marked {
        atoms[i].hat = .none
        atoms[i].markKey = nil
    }
    atoms.append(Atom(base: key, upper: upper))
    return .undone
}

/// The stroke stays on the d right before the key: `did` and `dad` are Vietnamese syllables too.
private func applyStroke(_ atoms: inout [Atom], key: Character, upper: Bool) -> MarkResult {
    guard let i = atoms.indices.last, atoms[i].base == "d" else { return .none }
    if !atoms[i].stroke, atoms[i].markKey == nil {
        atoms[i].stroke = true
        atoms[i].markKey = key
        return .applied
    }
    if atoms[i].stroke, atoms[i].markKey == key {
        atoms[i].stroke = false
        atoms[i].markKey = nil
        atoms.append(Atom(base: key, upper: upper))
        return .undone
    }
    return .none
}

private func markTarget(_ atoms: [Atom], _ cluster: Range<Int>, afterTone: Bool, _ intent: Intent) -> (Int, Hat)? {
    let open = cluster.filter { atoms[$0].hat == .none && atoms[$0].markKey == nil }
    let bases = String(cluster.map { atoms[$0].base })

    func hornTarget() -> Int? {
        if bases.hasPrefix("oa") { return nil }
        // In uo the horn goes on the o; normalizeHorn extends it to the u.
        if let j = cluster.dropFirst().first(where: { atoms[$0].base == "o" && atoms[$0 - 1].base == "u" }) {
            return open.contains(j) ? j : nil
        }
        return open.first { "uo".contains(atoms[$0].base) }
    }
    func breveTarget() -> Int? {
        open.first { atoms[$0].base == "a" }
    }

    switch intent {
    case .hornOrBreve:
        if let i = hornTarget() { return (i, .horn) }
        return breveTarget().map { ($0, .breve) }
    case .circumflex(let letter):
        // The key marks the nearest open vowel it repeats, right after it (`aa`), after the vowels
        // that follow (`vayaj` is vậy) or after the final (`vietej` is việt).
        // A tone key right before it breaks the pair: `oversee` and `verse` stay English.
        // Words like `data` and `photo` become Vietnamese syllables this way, so `English` lists them.
        guard !afterTone, let i = open.last(where: { atoms[$0].base == letter }) else { return nil }
        // A key that continues a real syllable stays a plain letter: `ngoeo` keeps its last o.
        if i != atoms.indices.last, isSyllable(atoms + [Atom(base: letter, upper: false)], tone: .none) { return nil }
        return (i, .circumflex)
    case .stroke:
        return nil
    }
}

/// A horn on either vowel of uo, uoi, uou means ươ. The open uo after an initial keeps its u: huơ, quơ, thuở.
private func normalizeHorn(_ atoms: [Atom]) -> [Atom] {
    let cluster = vowelRange(atoms)
    guard cluster.count >= 2,
          atoms[cluster.lowerBound].base == "u",
          atoms[cluster.lowerBound + 1].base == "o" else { return atoms }
    let pair = [cluster.lowerBound, cluster.lowerBound + 1]
    guard pair.contains(where: { atoms[$0].hat == .horn }) else { return atoms }
    let open = cluster.count == 2 && cluster.lowerBound > 0 && cluster.upperBound == atoms.count
    if open { return atoms }
    var out = atoms
    for i in pair { out[i].hat = .horn }
    return out
}

// MARK: - Spelling

/// Kiểu mới: oa, oe, uy and the three-vowel clusters built on them take the tone on the second vowel.
/// Everywhere else the tone sits on ơ ê ă â ô ư, in that order, else on the first vowel.
private let toneOnSecond: Set<String> = [
    "oa", "oe", "uy",
    "oai", "oay", "uai", "uay", "uya", "uyu",
]

/// Kiểu cũ puts the tone on the first vowel of these when nothing follows them (hòa, thúy).
private let classicFirstWhenOpen: Set<String> = ["oa", "oe", "uy"]

private let toneRank = ["ơ", "ê", "ă", "â", "ô", "ư"]

private let withTone: [String: [String]] = [
    "a": ["a", "á", "à", "ả", "ã", "ạ"],
    "ă": ["ă", "ắ", "ằ", "ẳ", "ẵ", "ặ"],
    "â": ["â", "ấ", "ầ", "ẩ", "ẫ", "ậ"],
    "e": ["e", "é", "è", "ẻ", "ẽ", "ẹ"],
    "ê": ["ê", "ế", "ề", "ể", "ễ", "ệ"],
    "i": ["i", "í", "ì", "ỉ", "ĩ", "ị"],
    "o": ["o", "ó", "ò", "ỏ", "õ", "ọ"],
    "ô": ["ô", "ố", "ồ", "ổ", "ỗ", "ộ"],
    "ơ": ["ơ", "ớ", "ờ", "ở", "ỡ", "ợ"],
    "u": ["u", "ú", "ù", "ủ", "ũ", "ụ"],
    "ư": ["ư", "ứ", "ừ", "ử", "ữ", "ự"],
    "y": ["y", "ý", "ỳ", "ỷ", "ỹ", "ỵ"],
]

private func compose(_ atoms: [Atom], tone: Tone, style: ToneStyle) -> String {
    guard !atoms.isEmpty else { return "" }
    let vowel = vowelRange(atoms)
    let open = vowel.upperBound == atoms.count
    let toneAt: Int? = vowel.isEmpty || tone == .none
        ? nil
        : vowel.lowerBound + toneOffset(atoms[vowel], style: style, open: open)
    var out = ""
    for (i, atom) in atoms.enumerated() {
        out.append(draw(atom, tone: i == toneAt ? tone : .none))
    }
    return out
}

/// `gi` and `qu` are initials when a vowel follows the i/u.
/// The tone sits on the last vowel run, which for one Vietnamese syllable is the only run.
private func vowelRange(_ atoms: [Atom]) -> Range<Int> {
    var hidden = Set<Int>()
    if atoms.count >= 3,
       atoms[0].base == "g", !atoms[0].stroke, atoms[0].hat == .none,
       atoms[1].base == "i", atoms[1].hat == .none,
       atoms.dropFirst(2).contains(where: \.isVowel) {
        hidden.insert(1)
    } else if atoms.count >= 3,
              atoms[0].base == "q",
              atoms[1].base == "u", atoms[1].hat == .none,
              atoms.dropFirst(2).contains(where: \.isVowel) {
        hidden.insert(1)
    }

    var best = atoms.count..<atoms.count
    var index = 0
    while index < atoms.count {
        if atoms[index].isVowel, !hidden.contains(index) {
            let start = index
            index += 1
            while index < atoms.count, atoms[index].isVowel, !hidden.contains(index) {
                index += 1
            }
            best = start..<index
        } else {
            index += 1
        }
    }
    return best
}

private func toneOffset(_ vowels: ArraySlice<Atom>, style: ToneStyle, open: Bool) -> Int {
    let keys = vowels.map(\.nucleus)
    let joined = keys.joined()
    if style == .classic, open, classicFirstWhenOpen.contains(joined) { return 0 }
    if toneOnSecond.contains(joined) { return 1 }
    for mark in toneRank {
        if let index = keys.firstIndex(of: mark) {
            return keys.distance(from: keys.startIndex, to: index)
        }
    }
    return 0
}

private func draw(_ atom: Atom, tone: Tone) -> String {
    if atom.stroke, atom.base == "d" {
        return atom.upper ? "Đ" : "đ"
    }
    let body: String
    if atom.isVowel, let forms = withTone[atom.nucleus] {
        body = forms[tone.rawValue]
    } else {
        body = String(atom.base)
    }
    if atom.upper { return body.uppercased() }
    return body
}

// MARK: - Validity

private let initials: Set<String> = [
    "", "b", "c", "ch", "d", "đ", "g", "gh", "gi", "h", "k", "kh", "l", "m", "n", "ng", "ngh", "nh",
    "p", "ph", "q", "qu", "r", "s", "t", "th", "tr", "v", "x",
]

private let finals: Set<String> = ["", "c", "ch", "m", "n", "ng", "nh", "p", "t"]

private let nuclei: Set<String> = [
    "a", "ă", "â", "e", "ê", "i", "o", "ô", "ơ", "u", "ư", "y",
    "ai", "ao", "au", "âu", "ay", "ây", "eo", "êu", "ia", "iê", "iu", "oa", "oă", "oe", "oi", "ôi",
    "ơi", "ua", "uâ", "uê", "ui", "uô", "uơ", "ưa", "ưi", "ươ", "ưu", "uy", "yê", "oo",
    "iêu", "yêu", "oai", "oao", "oay", "oây", "oeo", "uai", "uay", "uây", "uêu", "uôi", "ươi", "ươu", "uya", "uyê", "uyu",
]

/// Vowels still waiting for their circumflex. They are valid only while no tone is set.
private let unfinishedNuclei: Set<String> = ["ie", "ye", "uo", "uoi", "uou", "uye", "ieu", "yeu"]

/// The rules allow it and real Vietnamese words contain it, or could still grow into one.
private func isRealSyllable(_ atoms: [Atom], tone: Tone, style: ToneStyle) -> Bool {
    isSyllable(atoms, tone: tone)
        && Syllables.accepts(compose(atoms, tone: .none, style: style).lowercased(), tone: tone)
}

/// Initial + vowels + final, where a final c, ch, p or t takes only the sắc or nặng tone.
private func isSyllable(_ atoms: [Atom], tone: Tone) -> Bool {
    let cluster = vowelRange(atoms)
    func letters(_ slice: ArraySlice<Atom>) -> String {
        slice.map { $0.stroke ? "đ" : String($0.base) }.joined()
    }
    guard initials.contains(letters(atoms[..<cluster.lowerBound])) else { return false }
    if cluster.isEmpty { return true }

    let nucleus = atoms[cluster].map(\.nucleus).joined()
    guard nuclei.contains(nucleus) || (tone == .none && unfinishedNuclei.contains(nucleus)) else { return false }

    let final = letters(atoms[cluster.upperBound...])
    guard finals.contains(final) else { return false }
    if ["c", "ch", "p", "t"].contains(final) { return [.none, .sac, .nang].contains(tone) }
    return true
}
