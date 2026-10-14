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

    /// Keys that join two words into one code token. Only characters that never open a phrase in
    /// prose are here: `/` (và/hoặc), brackets (`[hoàn thành]`) and `*` (bold) also appear in Vietnamese.
    private static let glue: Set<Character> = ["_", "@", "\\", "=", "|", "&", "$", "^", "~"]

    var isComposing: Bool { !raw.isEmpty || isHolding }

    /// The pending text is the start of a cheat code, not a word.
    var isHolding: Bool { !held.isEmpty }

    func display(_ settings: Settings) -> String {
        isHolding ? held : Engine.render(raw, settings, after: previous, glued: glued)
    }

    /// A dot glues words in `foo.bar` and `README.md`, not after Vietnamese (`ừm...tôi`).
    private static func glues(_ ch: Character, afterVietnamese: Bool) -> Bool {
        glue.contains(ch) || (ch == "." && !afterVietnamese)
    }

    /// The text a finished word becomes. `expand` is true only for word-ending keys.
    func committed(_ settings: Settings, expand: Bool) -> String {
        if expand, let text = Engine.expansion(for: raw, settings) { return text }
        return display(settings)
    }

    /// Commits the word and remembers its language for the next one.
    mutating func finish(_ settings: Settings, expand: Bool) -> String {
        let text = committed(settings, expand: expand)
        let expanded = expand && Engine.expansion(for: raw, settings) != nil
        let language = expanded ? nil : Engine.analyze(raw, settings, after: previous, glued: glued).language
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
        return text
    }

    /// The typed keys as they are. The word counts as English from here on.
    mutating func finishRaw() -> String {
        let text = isHolding ? held : raw
        raw = ""
        held = ""
        previous = .english
        endsSentence = false
        glued = false
        afterVietnamese = false
        boundary = nil
        return text
    }

    mutating func forgetContext() {
        previous = nil
        glued = false
        afterVietnamese = false
    }

    mutating func push(_ ch: Character) -> Push {
        if isHolding { return pushHeld(ch) }
        if detectsTriggers, raw.isEmpty, ch == "/" {
            held = "/"
            return .consumed
        }
        if Engine.isComposing(ch) {
            raw.append(ch)
            return .consumed
        }
        let sentenceEnd = ".!?".contains(ch)
        if raw.isEmpty {
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
        raw.removeLast()
        return true
    }

    mutating func clear() {
        raw = ""
        held = ""
    }
}

enum Language {
    case vietnamese
    case english
}

enum Engine {
    static func isComposing(_ ch: Character) -> Bool {
        ch.isASCII && ch.isLetter
    }

    static func render(
        _ raw: String, _ settings: Settings = Settings(), after previous: Language? = nil, glued: Bool = false
    ) -> String {
        analyze(raw, settings, after: previous, glued: glued).text
    }

    /// The text a word shows and the language it reveals. `language` is nil when the
    /// word reads the same in both. `previous` is the language of the word before it.
    static func analyze(
        _ raw: String, _ settings: Settings, after previous: Language?, glued: Bool = false
    ) -> (text: String, language: Language?) {
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
        let out = compose(atoms, tone: tone, style: settings.toneStyle)
        let language: Language? = out == literal ? nil : .vietnamese
        guard settings.restoreRaw else { return (out, language) }
        if glued { return (literal, .english) }
        let word = raw.lowercased()
        if English.always.contains(word) || settings.keepEnglish.contains(word)
            || (previous == .english && English.context.contains(word)) {
            return (literal, .english)
        }
        let abbreviation = settings.abbreviation && settings.shorthand.contains(out.lowercased())
        guard isRealSyllable(atoms, tone: tone, style: settings.toneStyle) || abbreviation else {
            return (literal, .english)
        }
        return (out, language)
    }

    /// Looks the typed keys up in the macro table and copies the typed case onto the text.
    /// The table comes from `Settings.load()`, so its shortcuts are already lowercase.
    static func expansion(for raw: String, _ settings: Settings) -> String? {
        guard let first = raw.first else { return nil }
        let key = raw.lowercased()
        guard let macro = settings.macros.first(where: { $0.shortcut == key }) else { return nil }
        if raw.count >= 2, raw.allSatisfy(\.isUppercase) { return macro.text.uppercased() }
        if first.isUppercase, raw.dropFirst().allSatisfy(\.isLowercase) {
            return macro.text.prefix(1).uppercased() + String(macro.text.dropFirst())
        }
        return macro.text
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
