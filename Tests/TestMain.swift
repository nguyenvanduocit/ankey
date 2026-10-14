import Foundation

var failed = 0

func check(_ raw: String, _ want: String) {
    let got = Engine.render(raw)
    if got != want {
        failed += 1
        fputs("FAIL \(raw.debugDescription) → \(got.debugDescription), want \(want.debugDescription)\n", stderr)
    }
}

let telex: [(String, String)] = [
    ("a", "a"),
    ("as", "á"),
    ("af", "à"),
    ("ar", "ả"),
    ("ax", "ã"),
    ("aj", "ạ"),
    ("az", "az"),
    ("asz", "a"),
    ("ass", "ass"),
    ("asf", "à"),
    ("aa", "â"),
    ("aaa", "aa"),
    ("aas", "ấ"),
    ("aw", "ă"),
    ("aww", "aw"),
    ("aws", "ắ"),
    ("ee", "ê"),
    ("oo", "ô"),
    ("ooo", "oo"),
    ("ow", "ơ"),
    ("oww", "ow"),
    ("noww", "now"),
    ("Noww", "Now"),
    ("NOWW", "NOW"),
    ("howw", "how"),
    ("loww", "low"),
    ("uw", "ư"),
    ("dd", "đ"),
    ("ddd", "dd"),
    ("DD", "Đ"),
    ("As", "Á"),
    ("ans", "án"),
    ("anhs", "ánh"),
    ("san", "san"),
    ("sangs", "sáng"),
    ("sawsc", "sắc"),
    ("saswc", "sắc"),
    ("vieetj", "việt"),
    ("Vieetj", "Việt"),
    ("hoaf", "ho\u{00e0}"),
    ("khoongs", "kh\u{1ed1}ng"),
    ("khoer", "kho\u{1ebb}"),
    ("thuyr", "thu\u{1ef7}"),
    ("muas", "múa"),
    ("quas", "quá"),
    ("quoocs", "quốc"),
    ("gias", "giá"),
    ("gif", "gì"),
    ("nguyeenx", "nguyễn"),
    ("NGUYEENX", "NGUYỄN"),
    ("dduwowngf", "đường"),
    ("Dduwowngf", "Đường"),
    ("dduwowcj", "được"),
    ("uwowcs", "ước"),
    ("muwowif", "mười"),
    ("duwowis", "dưới"),
    ("chuyeenj", "chuyện"),
    ("tieengs", "tiếng"),
    ("ngoaif", "ngoài"),
    ("cuoois", "cuối"),
    ("hieeus", "hiếu"),
    ("yeeus", "yếu"),
    ("hocj", "học"),
    ("mowis", "mới"),
    ("nuis", "núi"),
    ("success", "success"),
    ("successs", "successs"),
    ("asbs", "asbs"),
    ("bass", "bass"),
    ("hello", "hello"),
    ("baa", "bâ"),
    ("baaa", "baa"),
    // Marks reach back to their vowel inside the syllable.
    ("moiw", "mơi"),
    ("nguoiw", "ngươi"),
    ("nguoiwf", "người"),
    ("duocwj", "dược"),
    ("duwocj", "dược"),
    ("quow", "quơ"),
    ("huow", "huơ"),
    ("uow", "ươ"),
    ("thuowngf", "thường"),
    ("thuongw", "thương"),
    ("anw", "ăn"),
    ("banw", "băn"),
    ("muaw", "mưa"),
    ("hoawcs", "hoắc"),
    ("data", "data"),
    ("beta", "beta"),
    ("pete", "pete"),
    ("toana", "toana"),
    // Text that cannot be a Vietnamese syllable shows as typed.
    ("smart", "smart"),
    ("text", "text"),
    ("hocf", "hocf"),
    ("pass", "pass"),
    ("world", "world"),
    ("coffee", "coffee"),
    ("did", "did"),
    ("dod", "dod"),
    ("ddc", "đc"),
    ("DDC", "ĐC"),
]

func check(_ raw: String, _ settings: Settings, _ want: String) {
    let got = Engine.render(raw, settings)
    if got != want {
        failed += 1
        fputs("FAIL \(raw.debugDescription) \(settings) → \(got.debugDescription), want \(want.debugDescription)\n", stderr)
    }
}

func expect<T: Equatable>(_ got: T, _ want: T, _ label: String) {
    if got != want {
        failed += 1
        fputs("FAIL \(label): got \(got), want \(want)\n", stderr)
    }
}

func checkAppRules() {
    var settings = Settings()
    settings.appRules = [
        AppRule(bundleID: "com.apple.Terminal", enabled: false),
        AppRule(bundleID: "com.tdesktop.Telegram", insertion: .direct),
    ]
    expect(settings.rule(for: "com.apple.Terminal").enabled, false, "rule off")
    var mode = AppRule(bundleID: "x")
    expect(mode.mode, .marked, "default mode")
    mode.mode = .direct
    expect([mode.enabled, mode.insertion == .direct], [true, true], "direct mode")
    mode.mode = .off
    expect([mode.enabled, mode.insertion == .direct, mode.mode == .off], [false, true, true], "off keeps the insertion")
    mode.mode = .marked
    expect([mode.enabled, mode.insertion == .marked], [true, true], "marked mode")
    expect(settings.rule(for: "com.tdesktop.Telegram").insertion, .direct, "rule direct")
    expect(settings.rule(for: "com.apple.TextEdit"), AppRule(bundleID: "com.apple.TextEdit"), "unknown app gets the default rule")
    expect(settings.rule(for: nil), AppRule(bundleID: ""), "nil bundle id")
    expect(settings.rule(for: "").enabled, true, "empty bundle id stays on")
    expect(Settings().rule(for: "com.apple.Terminal").enabled, true, "no rules switch nothing off")
}

func checkRelease() {
    expect(Version("1.2.3")?.parts, [1, 2, 3], "version plain")
    expect(Version("v1.10.0")?.parts, [1, 10, 0], "version v prefix")
    expect(Version("1.0") != nil, true, "version two parts")
    expect(Version("") == nil, true, "version empty")
    expect(Version("1.x") == nil, true, "version non numeric")
    expect(Version("1.2.3-beta") == nil, true, "version suffix")
    expect(Version("1.10.0")! > Version("1.9.9")!, true, "numeric compare")
    expect(Version("1.0")! == Version("1.0.0")!, true, "missing part is zero")
    expect(Version("1.0.1")! > Version("1.0")!, true, "longer wins when nonzero")

    func parse(_ data: Data) -> ReleaseInfo? {
        ReleaseInfo.parse(json: data, repo: "example/ankey")
    }

    let json = """
    {
      "tag_name": "v1.1.0",
      "body": "Fix tones",
      "assets": [
        {"name": "Ankey-1.1.0.zip", "browser_download_url": "https://github.com/example/ankey/releases/download/v1.1.0/Ankey-1.1.0.zip"},
        {"name": "Ankey-1.1.0.zip.sha256", "browser_download_url": "https://github.com/example/ankey/releases/download/v1.1.0/Ankey-1.1.0.zip.sha256"}
      ]
    }
    """
    let info = parse(Data(json.utf8))
    expect(info?.version.parts, [1, 1, 0], "release version")
    expect(info?.notes, "Fix tones", "release notes")
    expect(info?.zipURL.lastPathComponent, "Ankey-1.1.0.zip", "release zip")
    expect(info?.checksumURL.lastPathComponent, "Ankey-1.1.0.zip.sha256", "release checksum")

    func release(tag: String = "v1.1.0", zip: String, checksum: String) -> Data {
        Data("""
        {"tag_name": "\(tag)", "body": null, "assets": [
          {"name": "Ankey-1.1.0.zip", "browser_download_url": "\(zip)"},
          {"name": "Ankey-1.1.0.zip.sha256", "browser_download_url": "\(checksum)"}
        ]}
        """.utf8)
    }
    let good = "https://github.com/example/ankey/releases/download/v1.1.0/Ankey-1.1.0.zip"
    let goodSum = good + ".sha256"
    expect(parse(release(zip: good, checksum: goodSum))?.notes, "", "null body is empty notes")
    expect(parse(release(zip: "http://github.com/example/ankey/releases/download/v1.1.0/Ankey-1.1.0.zip", checksum: goodSum)) == nil, true, "http rejected")
    expect(parse(release(zip: "https://evil.example/example/ankey/releases/download/v1.1.0/Ankey-1.1.0.zip", checksum: goodSum)) == nil, true, "foreign host rejected")
    expect(parse(release(zip: "https://github.com/other/repo/releases/download/v1.1.0/Ankey-1.1.0.zip", checksum: goodSum)) == nil, true, "foreign repo rejected")
    expect(parse(release(tag: "latest", zip: good, checksum: goodSum)) == nil, true, "bad tag rejected")
    expect(parse(Data("{\"tag_name\": \"v1.1.0\", \"assets\": []}".utf8)) == nil, true, "no assets rejected")
    expect(parse(Data("not json".utf8)) == nil, true, "garbage rejected")

    let hex = String(repeating: "ab", count: 32)
    expect(parseChecksum("\(hex)  Ankey-1.1.0.zip\n"), hex, "checksum shasum line")
    expect(parseChecksum(hex.uppercased()), hex, "checksum uppercase lowered")
    expect(parseChecksum("abc"), nil, "checksum too short")
    expect(parseChecksum(String(repeating: "zz", count: 32)), nil, "checksum not hex")
}

/// Prints the cost of one `Engine.analyze` over a mix of words, with many learned words.
func checkAnalyzeTiming() {
    var settings = Settings()
    settings.adjust = Dictionary(uniqueKeysWithValues: (0..<300).map { ("userword\($0)", 2) })
    let words = ["test", "reset", "hello", "vieetj", "tooi", "sex", "chaos", "cos", "thuowngf", "commit", "as", "xinf"]
    let rounds = 100_000
    var sink = 0
    let start = Date()
    for i in 0..<rounds {
        let result = Engine.analyze(words[i % words.count], settings, after: i % 3 == 0 ? .english : .vietnamese)
        sink &+= result.text.utf8.count
    }
    let perCall = Date().timeIntervalSince(start) / Double(rounds) * 1_000_000
    print("analyze with 300 learned words: \(String(format: "%.3f", perCall)) us per call (\(sink))")
}

func checkShorthand() {
    check("ddc", Settings(), "\u{0111}c")
    var custom = Settings()
    custom.shorthand = ["\u{0111}t"]
    check("ddt", custom, "\u{0111}t")
    check("DDT", custom, "\u{0110}T")
    check("ddc", custom, "ddc")
    var none = Settings()
    none.shorthand = []
    check("ddc", none, "ddc")
    custom.abbreviation = false
    check("ddt", custom, "ddt")
}

func checkSettings() {
    let classic = Settings(toneStyle: .classic)
    // Classic style moves the tone only on open oa, oe, uy.
    for (raw, want) in [
        ("hoaf", "h\u{00f2}a"), ("khoer", "kh\u{1ecf}e"), ("thuys", "th\u{00fa}y"),
        ("hoanf", "ho\u{00e0}n"), ("huynhf", "hu\u{1ef3}nh"), ("ngoaif", "ngo\u{00e0}i"),
        ("quas", "qu\u{00e1}"), ("hoawcs", "ho\u{1eaf}c"), ("tieengs", "ti\u{1ebf}ng"),
    ] { check(raw, classic, want) }

    let rawOff = Settings(restoreRaw: false)
    check("hocf", rawOff, "h\u{00f2}c")
    check("text", rawOff, "t\u{1ebd}t")
    check("vieetj", rawOff, "vi\u{1ec7}t")

    check("ddc", Settings(abbreviation: false), "ddc")
    check("DDC", Settings(abbreviation: false), "DDC")
    check("ddc", Settings(restoreRaw: false, abbreviation: false), "\u{0111}c")
    check("ddduwowngf", Settings(abbreviation: false), "dduwowngf")
    check("dduwowngf", Settings(abbreviation: false), "\u{0111}\u{01b0}\u{1edd}ng")

    let suite = "ankey.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    if Settings.load(from: defaults) != Settings() {
        failed += 1
        fputs("FAIL empty defaults do not load as Settings()\n", stderr)
    }
    let custom = Settings(toneStyle: .classic, restoreRaw: false, abbreviation: false, escClears: false)
    custom.save(to: defaults)
    if Settings.load(from: defaults) != custom {
        failed += 1
        fputs("FAIL Settings save/load round trip\n", stderr)
    }
}

/// Telex keys that type `syllable`. `inline` puts every mark right after its letter,
/// `deferred` types the horn and breve key after the plain letters.
func telexKeys(_ syllable: String) -> (inline: String, deferred: String) {
    var inline = "", plain = "", tone = ""
    var horn = false
    for scalar in syllable.decomposedStringWithCanonicalMapping.unicodeScalars {
        switch scalar.value {
        case 0x0111: inline += "dd"; plain += "dd"
        case 0x0302: inline += String(inline.last!); plain += String(plain.last!)
        case 0x0306, 0x031B: inline += "w"; horn = true
        case 0x0301: tone = "s"
        case 0x0300: tone = "f"
        case 0x0309: tone = "r"
        case 0x0303: tone = "x"
        case 0x0323: tone = "j"
        default:
            inline += String(scalar)
            plain += String(scalar)
        }
    }
    return (inline + tone, plain + (horn ? "w" : "") + tone)
}

/// Every attested syllable types out in both key orders, in either tone placement.
func checkSyllables() {
    func render(_ raw: String, _ style: ToneStyle) -> String {
        let settings = Settings(toneStyle: style)
        return Engine.render(raw, settings).precomposedStringWithCanonicalMapping
    }
    var english = 0
    for syllable in Syllables.all {
        let keys = telexKeys(syllable)
        for (mode, raw) in [("inline", keys.inline), ("deferred", keys.deferred)] {
            // The keys of an always-English word type that word, by design.
            if English.always.contains(raw) {
                english += 1
                continue
            }
            let want = syllable.precomposedStringWithCanonicalMapping
            if render(raw, .modern) != want && render(raw, .classic) != want {
                failed += 1
                fputs("FAIL syllable \(mode) \(raw) → \(render(raw, .modern)), want \(syllable)\n", stderr)
            }
        }
    }
    print("syllables \(Syllables.all.count), \(english) key orders typed as English words")
}

/// A repeated a, e or o undoes a circumflex only right after the marked vowels.
func checkDistantRepeat() {
    for word in ["reserved", "needed", "agreement", "weekend", "toronto", "difference", "defense"] {
        check(word, word)
    }
    // A tone key between the vowels breaks the repeat: no letter is lost.
    for word in ["reference", "references", "preference", "therefore", "referee", "interference"] {
        check(word, word)
    }
}

/// A circumflex key may come after the vowels that follow it or after the final.
func checkLateCircumflex() {
    for (raw, want) in [
        ("vayaj", "v\u{1ead}y"), ("toio", "t\u{00f4}i"), ("toioj", "t\u{1ed9}i"), ("nguoio", "ngu\u{00f4}i"),
        ("caua", "c\u{00e2}u"), ("vietej", "vi\u{1ec7}t"), ("vietes", "vi\u{1ebf}t"), ("hocoj", "h\u{1ed9}c"),
        ("Vietej", "Vi\u{1ec7}t"), ("VIETEJ", "VI\u{1ec6}T"),
        // A key that continues a real syllable stays a plain letter.
        ("ngoeos", "ng\u{00f3}eo"),
    ] { check(raw, want) }
    // A tone key right before the vowel breaks the pair, and English words stay English.
    for word in [
        "data", "beta", "verse", "oversee", "video", "photo", "queue", "pete", "reset", "reference", "reserved",
        "toronto", "banana", "americano", "alabama",
    ] { check(word, word) }
    // Words that are common in Vietnamese win over the English look-alike.
    check("theme", "th\u{00ea}m")
}

func checkBuiltInEnglish() {
    // The built-in list keeps these English with no setting saved.
    for word in ["test", "reset", "boot", "row", "saw", "law", "door", "asap"] {
        check(word, Settings(), word)
        check(word.capitalized, Settings(), word.capitalized)
        check(word.uppercased(), Settings(), word.uppercased())
    }
    check("tes", Settings(), "t\u{00e9}")
    // The built-in words are part of restoring raw text.
    check("test", Settings(restoreRaw: false), "t\u{00e9}t")
    // Words people type as Vietnamese stay Vietnamese by default.
    for (raw, want) in [("cams", "c\u{00e1}m"), ("tets", "t\u{00e9}t"), ("cos", "c\u{00f3}"), ("nos", "n\u{00f3}"), ("gif", "g\u{00ec}"), ("aj", "\u{1ea1}"), ("oo", "\u{00f4}"), ("chaos", "ch\u{00e1}o")] {
        check(raw, Settings(), want)
    }
    // The Vietnamese-common ones stay English right after an English word.
    expect(Engine.render("chaos", Settings(), after: .english), "chaos", "chaos after English")
    expect(Engine.render("chaos", Settings(), after: .vietnamese), "ch\u{00e1}o", "chaos after Vietnamese")
    // Nothing built in converts: every word of the lists stays as typed, in any case.
    for word in English.always { check(word, Settings(), word) }
    for word in English.context {
        expect(Engine.render(word, Settings(), after: .english), word, "\(word) after English")
    }
}

/// One score decides the language: the built-in band, plus one after an English word, plus the learned adjustment.
/// The word stays as typed from 2 up.
func checkScore() {
    func settings(_ word: String, _ adjust: Int) -> Settings {
        var s = Settings()
        s.adjust = [word: adjust]
        return s
    }
    // A context word (band 1) after Vietnamese needs +1; an unlisted word stays Vietnamese after English.
    check("chaos", settings("chaos", 1), "chaos")
    check("chaos", settings("chaos", 0), "ch\u{00e1}o")
    expect(Engine.render("cos", Settings(), after: .english), "c\u{00f3}", "cos 0 after English")
    // A context word (band 1) needs +1, or the English word before it.
    check("sex", settings("sex", 1), "sex")
    expect(Engine.render("sex", Settings(), after: .english), "sex", "sex after English")
    // An always word (band 2) turns Vietnamese from -1, but the English word before it adds one back.
    check("test", settings("test", -1), "t\u{00e9}t")
    expect(Engine.render("test", settings("test", -1), after: .english), "test", "test -1 after English")
    check("test", settings("test", -2), "t\u{00e9}t")
    expect(Engine.render("test", settings("test", -2), after: .english), "t\u{00e9}t", "test -2 after English")
    // The adjustment belongs to one word, in any case.
    check("tes", settings("chaos", 2), "t\u{00e9}")
    check("CHAOS", settings("chaos", 1), "CHAOS")
    // The gates stay outside the score: a word that is no syllable stays English, and so does code.
    check("hello", settings("hello", -2), "hello")
    expect(Engine.render("chaos", settings("chaos", -2), after: .english, glued: true), "chaos", "glued word")
    // With raw restore off nothing is judged.
    var off = settings("chaos", 2)
    off.restoreRaw = false
    check("chaos", off, "ch\u{00e1}o")
}

func checkAdjustStore() {
    let suite = "ankey.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = AdjustStore(defaults: defaults)
    expect(store.words, [:], "nothing learned yet")
    store.set("sex", to: 1)
    store.set("test", to: -1)
    expect(store.words, ["sex": 1, "test": -1], "set")
    expect(AdjustStore(defaults: defaults).words, ["sex": 1, "test": -1], "written through")
    store.set("sex", to: 9)
    store.set("test", to: -9)
    expect(store.words, ["sex": 2, "test": -2], "clamped to the scale")
    store.set("sex", to: 0)
    expect(store.words, ["test": -2], "zero forgets the word")
    expect(AdjustStore(defaults: defaults).words, ["test": -2], "forgotten for good")
    store.set("banj", to: 2)
    expect(store.words, ["test": -2], "a word with no English side is not kept")

    // Stored rows are cleaned the way the engine reads them.
    defaults.set(["Sex ": 1, "": 2, "own": 0, "chaos": 9, "test": -9, "banj": 2], forKey: "wordAdjust")
    expect(AdjustStore(defaults: defaults).words, ["sex": 1, "chaos": 2, "test": -2], "stored rows cleaned")
    defaults.set(["banj": 2, "tooi": 1, "loop": -1], forKey: "wordAdjust")
    expect(AdjustStore(defaults: defaults).words, ["loop": -1], "words learned without an English side are dropped")
    defaults.set(5, forKey: "wordAdjust")
    expect(AdjustStore(defaults: defaults).words, [:], "wrong type")
    defaults.set(["a": "x"], forKey: "wordAdjust")
    expect(AdjustStore(defaults: defaults).words, [:], "wrong value type")

    // Settings carry a copy for the engine and never write it back, so a settings window opened before a
    // correction cannot erase it.
    store.set("sex", to: 1)
    var settings = Settings.load(from: defaults, adjust: store)
    expect(settings.adjust, store.words, "load copies the store")
    settings.adjust = ["stale": 2]
    settings.save(to: defaults)
    expect(store.words, ["test": -2, "sex": 1], "save leaves the store alone")
    expect(AdjustStore(defaults: defaults).words, ["test": -2, "sex": 1], "save writes no adjustment")
}

/// Erasing a whole word and typing the same keys again says the engine chose the wrong language.
func checkCorrection() {
    let none = Settings()
    func type(_ session: inout Session, _ keys: String, _ settings: Settings = Settings()) -> Correction? {
        var found: Correction?
        for ch in keys {
            _ = session.push(ch)
            if let correction = session.correction(settings) { found = correction }
        }
        return found
    }
    func erase(_ session: inout Session) {
        while session.pop() {}
    }

    // Vietnamese was shown, so the retype turns English. `sex` has band 1, one step is enough.
    var session = Session()
    expect(type(&session, "sex"), nil, "the first typing is no correction")
    expect(session.display(none), "s\u{1ebd}", "sex shows sẽ")
    erase(&session)
    expect(type(&session, "se"), nil, "no correction before the last key")
    expect(type(&session, "x"), Correction(word: "sex", adjust: 1), "retyped sex")
    var learned = none
    learned.adjust = ["sex": 1]
    expect(session.display(learned), "sex", "the retype shows English")
    expect(type(&session, "y"), nil, "a correction fires once")

    // English was shown, so the retype turns Vietnamese.
    session = Session()
    _ = type(&session, "test")
    erase(&session)
    expect(type(&session, "test"), Correction(word: "test", adjust: -1), "test turns Vietnamese")
    // A word the lists know as English turns English even when Vietnamese wins by default.
    session = Session()
    _ = type(&session, "cos")
    erase(&session)
    expect(type(&session, "cos"), Correction(word: "cos", adjust: 2), "cos turns English")
    // English needs evidence. A word the built-in lists do not know as English never turns English, so
    // `banj` and `hocj` (no word of either language) keep their Vietnamese reading.
    for word in ["banj", "hocj", "tooi"] {
        session = Session()
        _ = type(&session, word)
        erase(&session)
        expect(type(&session, word), nil, "\(word) has no English side")
    }
    session = Session()
    _ = type(&session, "banj")
    expect(session.display(none), "b\u{1ea1}n", "banj shows bạn")
    erase(&session)
    _ = type(&session, "banj")
    expect(session.display(none), "b\u{1ea1}n", "banj shows bạn after the retype")
    // An earlier correction is undone from the other side.
    var taught = none
    taught.adjust = ["sex": 1]
    session = Session()
    _ = type(&session, "sex", taught)
    erase(&session)
    expect(type(&session, "sex", taught), Correction(word: "sex", adjust: 0), "sex taught English, then turned back")
    // Case does not matter.
    session = Session()
    _ = type(&session, "Sex")
    erase(&session)
    expect(type(&session, "sex"), Correction(word: "sex", adjust: 1), "case is ignored")

    // Backspace has other uses: none of these is a correction.
    session = Session()
    _ = type(&session, "sex")
    erase(&session)
    expect(type(&session, "sez"), nil, "a typo fix is another word")
    erase(&session)
    expect(type(&session, "sex"), nil, "a departed word is forgotten")
    session = Session()
    _ = type(&session, "sex")
    _ = session.pop()
    expect(type(&session, "x"), nil, "a partial delete")
    session = Session()
    _ = type(&session, "sex")
    erase(&session)
    _ = session.push(" ")
    expect(type(&session, "sex"), nil, "another key between")
    session = Session()
    _ = type(&session, "as")
    erase(&session)
    expect(type(&session, "as"), nil, "a Telex word of two letters")
    session = Session()
    _ = type(&session, "hello")
    erase(&session)
    expect(type(&session, "hello"), nil, "one text only, nothing to choose")
    session = Session()
    _ = type(&session, "sex")
    session.clear()
    expect(type(&session, "sex"), nil, "Esc is no erase")
    var raw = none
    raw.restoreRaw = false
    session = Session()
    _ = type(&session, "sex", raw)
    erase(&session)
    expect(type(&session, "sex", raw), nil, "raw restore off")

    // A word the user committed and then deleted in the document.
    func commit(_ session: inout Session, _ keys: String, boundary: Character = " ") -> String {
        for ch in keys { _ = session.push(ch) }
        precondition(session.push(boundary) == .commit)
        return session.finish(none)
    }
    func delete(_ session: inout Session, _ count: Int) {
        for _ in 0..<count { session.deleted() }
    }
    session = Session()
    var text = commit(&session, "sex")
    expect(text, "s\u{1ebd}", "committed as sẽ")
    delete(&session, text.count + 1)
    expect(type(&session, "sex"), Correction(word: "sex", adjust: 1), "retyped after the commit")
    session = Session()
    text = commit(&session, "sex")
    delete(&session, text.count)
    expect(type(&session, "sex"), nil, "the boundary key is still there")
    session = Session()
    text = commit(&session, "sex")
    delete(&session, text.count + 2)
    expect(type(&session, "sex"), nil, "one delete too many")
    session = Session()
    text = commit(&session, "sex")
    delete(&session, 1)
    _ = session.push("a")
    delete(&session, text.count)
    expect(type(&session, "sex"), nil, "typing in between")
    session = Session()
    text = commit(&session, "sex")
    delete(&session, text.count + 1)
    session.forgetContext()
    expect(type(&session, "sex"), nil, "the caret moved")
    // The erased word does not count as the word before it.
    session = Session()
    _ = commit(&session, "xinf")
    text = commit(&session, "test")
    delete(&session, text.count + 1)
    expect(type(&session, "test"), Correction(word: "test", adjust: -1), "context from before the erased word")
}

/// A tone key typed twice undoes the tone. When the undone text is a word the lists know as English, that is
/// what the user reached for (`coss` is `cos`). Any other word keeps every key it was typed with.
func checkToneUndo() {
    for (typed, want) in [
        ("coss", "cos"), ("noss", "nos"), ("giff", "gif"), ("sexx", "sex"), ("boxx", "box"),
        ("Coss", "Cos"), ("COSS", "COS"),
    ] { check(typed, want) }
    expect(Engine.render("coss", Settings(), after: .vietnamese), "cos", "coss after Vietnamese")
    // The letters after the undo key continue the word.
    check("cosst", "cost")
    // English words that need both keys stay whole, and so does any word the lists do not know.
    for word in [
        "boss", "pass", "class", "mass", "less", "loss", "miss", "off", "carry", "marry", "buff", "ass",
        "address", "assert", "assertEqual", "assist", "error", "staff", "success", "process", "message", "coffee",
        "banjj", "hocjj",
    ] { check(word, word) }
    // Marks undo the same way.
    for (typed, want) in [("tooo", "too"), ("seee", "see"), ("saww", "saw")] { check(typed, want) }
    // The word counts as English afterwards.
    var session = Session()
    for ch in "coss" { _ = session.push(ch) }
    expect(session.finish(Settings()), "cos", "committed as cos")
    for ch in "as" { _ = session.push(ch) }
    expect(session.display(Settings()), "as", "as after English")
}

func checkContext() {
    let s = Settings()
    expect(Engine.render("as", s, after: nil), "\u{00e1}", "as without context")
    expect(Engine.render("as", s, after: .vietnamese), "\u{00e1}", "as after Vietnamese")
    expect(Engine.render("as", s, after: .english), "as", "as after English")
    // Only the ambiguous words react to the context.
    expect(Engine.render("cas", s, after: .english), "c\u{00e1}", "cas after English")
    expect(Engine.render("own", s, after: .english), "own", "own after English")
    expect(Engine.render("own", s, after: .vietnamese), "\u{01a1}n", "own after Vietnamese")
    expect(Engine.render("as", Settings(restoreRaw: false), after: .english), "\u{00e1}", "restoreRaw off")

    func typed(_ session: inout Session, _ word: String) -> String {
        for ch in word { _ = session.push(ch) }
        return session.finish(s)
    }
    var session = Session()
    expect(typed(&session, "commit"), "commit", "english word")
    expect(typed(&session, "as"), "as", "as after commit")
    expect(typed(&session, "cams"), "c\u{00e1}m", "Vietnamese word")
    expect(typed(&session, "as"), "\u{00e1}", "as after Vietnamese word")
    // A neutral word keeps the language before it.
    _ = typed(&session, "commit")
    expect(typed(&session, "ba"), "ba", "neutral word")
    expect(typed(&session, "as"), "as", "as after neutral word")
    // A sentence end starts fresh.
    _ = typed(&session, "commit")
    expect(session.push("."), .pass, "dot with nothing composing")
    expect(session.push(" "), .pass, "space after the dot")
    expect(typed(&session, "as"), "\u{00e1}", "as after a sentence end")
    for ch in "commit" { _ = session.push(ch) }
    expect(session.push("."), .commit, "dot commits")
    _ = session.finish(s)
    expect(session.push(" "), .pass, "space after the word and dot")
    expect(typed(&session, "as"), "\u{00e1}", "as after word and dot")
    // Context is forgotten on request.
    _ = typed(&session, "commit")
    session.forgetContext()
    expect(typed(&session, "as"), "\u{00e1}", "as after forgetContext")
    // A dot after forgetContext glues the next word like in a fresh session, whatever came before.
    func afterDot(_ session: inout Session) -> String {
        for ch in ".baf" { _ = session.push(ch) }
        return session.display(s)
    }
    var forgotten = Session()
    for ch in "xinf" { _ = forgotten.push(ch) }
    _ = forgotten.push(" ")
    _ = forgotten.finish(s)
    forgotten.forgetContext()
    var fresh = Session()
    expect(afterDot(&forgotten), afterDot(&fresh), "forgetContext matches a fresh session")
}

/// Types a line the way the controller does: each key joins the word, or ends it.
func typeLine(_ line: String, _ settings: Settings = Settings()) -> String {
    var session = Session()
    var document = ""
    for ch in line {
        var answer = session.push(ch)
        if answer == .flush {
            document += session.finish(settings)
            answer = session.push(ch)
        }
        switch answer {
        case .consumed, .flush, .cheat: break
        case .pass: document.append(ch)
        case .commit:
            document += session.finish(settings)
            document.append(ch)
        }
    }
    return document + session.finish(settings)
}

/// A word glued to code punctuation is code, not Vietnamese.
func checkCodeContext() {
    for line in [
        "my_var", "foo.bar(x)", "user@bar", "x=var", "a|bar", "a&bar", "$bar", "a^bar", "~bar", "\\bar",
        "www.google.com", "README.md", "package.json", "get_user_by_row", "foo.row", "v2.reset",
    ] {
        expect(typeLine(line), line, "code token \(line)")
    }
    // Brackets, slashes and bold marks open Vietnamese phrases too.
    expect(typeLine("[hoanf thanhf]"), "[ho\u{00e0}n th\u{00e0}nh]", "bracket")
    expect(typeLine("vaf/hoawcj"), "v\u{00e0}/ho\u{1eb7}c", "slash")
    expect(typeLine("**hoanf**"), "**ho\u{00e0}n**", "bold")
    expect(typeLine("<hoanf>"), "<ho\u{00e0}n>", "angle bracket")
    // Spaces end the token, and Vietnamese before or after a dot or comma stays Vietnamese.
    expect(typeLine("my_var vas"), "my_var v\u{00e1}", "space ends the token")
    expect(typeLine("tooi.vas"), "t\u{00f4}i.v\u{00e1}", "dot after Vietnamese")
    expect(typeLine("uwf...tooi"), "\u{1eeb}...t\u{00f4}i", "ellipsis")
    expect(typeLine("vas.vas"), "v\u{00e1}.v\u{00e1}", "dot after a Vietnamese word")
    expect(typeLine("anh,vas"), "anh,v\u{00e1}", "comma is not code")
    expect(typeLine("(vas)"), "(v\u{00e1})", "parenthesis is not code")
    expect(typeLine("anh-vas"), "anh-v\u{00e1}", "hyphen is not code")
    expect(typeLine("my_var", Settings(restoreRaw: false)), "my_v\u{1ea3}", "restoreRaw off")
}

func checkRawRestore() {
    let none = Settings()
    var session = Session()
    for ch in "tets" { _ = session.push(ch) }
    expect(session.display(none), "t\u{00e9}t", "converted before Esc")
    expect(session.finishRaw(), "tets", "Esc gives the typed keys")
    expect(session.isComposing, false, "nothing composing after Esc")
    // The word was English, so the next ambiguous word stays English.
    for ch in "as" { _ = session.push(ch) }
    expect(session.display(none), "as", "as after Esc")
    _ = session.finish(none)
    var noww = Session()
    for ch in "noww" { _ = noww.push(ch) }
    expect(noww.display(none), "now", "undone mark")
    expect(noww.finishRaw(), "noww", "Esc restores every key")
}

func checkAttested() {
    // The rules allow doé, but no real word has it.
    check("does", "does")
    // A conversion stays visible while the word can still grow into a real syllable.
    check("thuow", "thu\u{01a1}")
    check("vieet", "vi\u{00ea}t")
    check("vieetj", "vi\u{1ec7}t")
    check("nguoiwf", "ng\u{01b0}\u{1edd}i")
}
func checkEncoding() {
    func conv(_ text: String, _ encoding: OutputEncoding) -> String { encoding.convert(text) }
    func scalars(_ text: String) -> [UInt32] { text.unicodeScalars.map(\.value) }

    // Unicode is the identity.
    expect(conv("Vi\u{1ec7}t Nam", .unicode), "Vi\u{1ec7}t Nam", "unicode is unchanged")

    // TCVN3: one byte per letter, shown as the Latin-1 scalar of that byte.
    expect(scalars(conv("vi\u{1ec7}t nam", .tcvn3)), [0x76, 0x69, 0xD6, 0x74, 0x20, 0x6E, 0x61, 0x6D], "tcvn3 việt nam")
    expect(scalars(conv("\u{0111}\u{01b0}\u{1edd}ng", .tcvn3)), [0xAE, 0xAD, 0xEA, 0x6E, 0x67], "tcvn3 đường")
    expect(scalars(conv("\u{0110}\u{01af}\u{1edc}NG", .tcvn3)), [0xA7, 0xA6, 0xEA, 0x4E, 0x47], "tcvn3 ĐƯỜNG: accented capitals share the lowercase byte")
    expect(conv("\u{00c1}", .tcvn3), conv("\u{00e1}", .tcvn3), "tcvn3 Á shares the byte of á")

    // VNI Windows: base letter then a mark byte; ơ ư đ and a few vowels are single bytes.
    expect(scalars(conv("Vi\u{1ec7}t Nam", .vniWindows)), [0x56, 0x69, 0x65, 0xE4, 0x74, 0x20, 0x4E, 0x61, 0x6D], "vni Việt Nam")
    expect(scalars(conv("\u{0111}\u{01b0}\u{1edd}ng", .vniWindows)), [0xF1, 0xF6, 0xF4, 0xF8, 0x6E, 0x67], "vni đường")
    expect(scalars(conv("\u{1ea4}", .vniWindows)), [0x41, 0xC1], "vni Ấ")
    expect(scalars(conv("\u{00f4}", .vniWindows)), [0x6F, 0xE2], "vni ô is o + circumflex byte")
    expect(scalars(conv("\u{1ed1}", .vniWindows)), [0x6F, 0xE1], "vni ố")

    // Text that is not Vietnamese passes through, and a decomposed letter converts like the precomposed one.
    expect(conv("hello, 123 !", .tcvn3), "hello, 123 !", "tcvn3 leaves ASCII alone")
    expect(conv("hello, 123 !", .vniWindows), "hello, 123 !", "vni leaves ASCII alone")
    expect(conv("a\u{0301}", .tcvn3), conv("\u{00e1}", .tcvn3), "tcvn3 decomposed á")
    expect(conv("a\u{0301}", .vniWindows), conv("\u{00e1}", .vniWindows), "vni decomposed á")
    expect(conv("", .tcvn3), "", "empty text")

    // Every Vietnamese letter converts, to Latin-1 scalars, and no two lowercase letters collide.
    let lower = "àáảãạăằắẳẵặâầấẩẫậđèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵ"
    let upper = lower.uppercased()
    expect(lower.count, 67, "lowercase letter count")
    expect(upper.count, 67, "uppercase letter count")
    for encoding in [OutputEncoding.tcvn3, .vniWindows] {
        var seen = Set<[UInt32]>()
        for letter in lower {
            let out = scalars(conv(String(letter), encoding))
            expect(out.isEmpty || out.contains { $0 < 0x41 || $0 > 0xFE }, false, "\(encoding) \(letter) stays in 0x41...0xFE")
            expect(seen.insert(out).inserted, true, "\(encoding) \(letter) is unique")
        }
    }
    // A few letters already sit on their own Latin-1 byte, so they come out unchanged.
    expect(conv("\u{00fd}", .tcvn3), "\u{00fd}", "tcvn3 ý is its own byte")
    expect(conv("\u{00ec}\u{00ed}\u{00cc}\u{00cd}", .vniWindows), "\u{00ec}\u{00ed}\u{00cc}\u{00cd}", "vni ì í Ì Í are their own bytes")

    // Settings: default, round trip, a bad value, and the per-app override.
    let suite = "ankey.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    expect(Settings.load(from: defaults).encoding, .unicode, "encoding default")
    var settings = Settings()
    settings.encoding = .tcvn3
    settings.appRules = [
        AppRule(bundleID: "com.microsoft.Word", encoding: .vniWindows),
        AppRule(bundleID: "com.apple.TextEdit"),
    ]
    settings.save(to: defaults)
    expect(Settings.load(from: defaults), settings, "encoding round trip")
    expect(Settings.load(from: defaults).appRules.map(\.encoding), [.vniWindows, nil], "rule encoding round trip")
    defaults.set("klingon", forKey: "encoding")
    expect(Settings.load(from: defaults).encoding, .unicode, "bad global encoding falls back")
    expect(AppRule(stored: ["bundleID": "x", "encoding": "klingon"])?.encoding, nil, "bad rule encoding follows the default")
    expect(AppRule(stored: ["bundleID": "x"])?.encoding, nil, "old rule without encoding follows the default")

    expect(settings.encoding(for: settings.rule(for: "com.microsoft.Word")), .vniWindows, "app override wins")
    expect(settings.encoding(for: settings.rule(for: "com.apple.TextEdit")), .tcvn3, "rule without override follows the default")
    expect(settings.encoding(for: settings.rule(for: "com.unknown.App")), .tcvn3, "unknown app follows the default")
    expect(settings.encoding(for: settings.rule(for: nil)), .tcvn3, "no bundle id follows the default")
}

func checkStats() {
    let suite = "ankey.tests.stats.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let noon = Date(timeIntervalSince1970: 1_792_000_000)

    // Off by default: nothing is stored.
    expect(Settings().collectStats, false, "stats default off")
    StatsStore.record(.wordKept, now: noon, defaults: defaults)
    expect(StatsStore.load(from: defaults), StatsLog(), "off records nothing")
    expect(defaults.object(forKey: "stats") == nil, true, "off writes no key")

    // On: events add up per day, survive a reload, and clear on request.
    var settings = Settings()
    settings.collectStats = true
    settings.save(to: defaults)
    expect(Settings.load(from: defaults).collectStats, true, "stats setting round trip")
    StatsStore.record(.wordKept, now: noon, defaults: defaults)
    StatsStore.record(.wordKept, now: noon, defaults: defaults)
    StatsStore.record(.escRestoredRaw, now: noon, defaults: defaults)
    let day = StatsLog.dayKey(noon)
    let log = StatsStore.load(from: defaults)
    expect(log.days[day]?[.wordKept], 2, "counts add up")
    expect(log.days[day]?[.escRestoredRaw], 1, "events count apart")
    expect(log.days[day]?[.directFallback], 0, "unseen event is zero")
    StatsStore.clear(from: defaults)
    expect(StatsStore.load(from: defaults), StatsLog(), "clear empties the log")

    // Stored rows: bad day keys, unknown events and non-positive counts are dropped.
    let loaded = StatsLog(stored: [
        "2026-10-15": ["wordKept": 3, "wordChanged": -1, "secretWord": 9],
        "xinchao": ["wordKept": 1],
        "2026-1-5": ["wordKept": 1],
    ])
    expect(loaded.ordered.map(\.day), ["2026-10-15"], "only well-formed day keys load")
    expect(loaded.days["2026-10-15"]?.stored, ["wordKept": 3], "only known positive counters load")

    // Thirty days kept, oldest dropped.
    var long = StatsLog()
    for index in 1...40 { long.record(.wordKept, on: String(format: "2026-09-%02d", index)) }
    expect(long.days.count, StatsLog.keepDays, "log keeps thirty days")
    expect(long.ordered.first?.day, "2026-09-11", "oldest days go first")

    expect(statsEvent(raw: "vieetj", committed: "vi\u{1ec7}t"), .wordChanged, "converted word is changed")
    expect(statsEvent(raw: "hello", committed: "hello"), .wordKept, "same word is kept")
    expect(statsEvent(raw: "", committed: ""), nil, "empty word says nothing")

    // The payload: the exact keys, written down here on purpose. A new field fails this test until the
    // list changes with it, so nothing joins the data without a visible edit.
    var sample = StatsLog()
    for event in StatsEvent.allCases { sample.record(event, on: "2026-10-15") }
    var tcvn = Settings()
    tcvn.encoding = .tcvn3
    tcvn.appRules = [AppRule(bundleID: "com.secret.App")]
    let payload = StatsPayload(appVersion: "1.4.0", macOS: "26.4", settings: tcvn, log: sample)
    let events = payload.events(installID: "11111111-2222-3333-4444-555555555555")
    expect(events.count, 1, "one event per day")
    expect(Set(events[0].attributes.keys), [
        "appVersion", "macOS", "toneStyle", "encoding", "appRuleCount", "day", "installID",
        "wordChanged", "wordKept", "escRestoredRaw", "directFallback",
    ], "payload attributes are the allowlist")
    let strings = events[0].attributes.values.compactMap { value -> String? in
        if case .string(let text) = value { return text }
        return nil
    }
    expect(Set(strings), ["1.4.0", "26.4", "modern", "tcvn3", "2026-10-15", "11111111-2222-3333-4444-555555555555"], "payload strings are version, settings, day and install id only")
    expect(events[0].attributes["appRuleCount"], .int(1), "payload counts rules without naming them")
    expect(Set(payload.events(installID: nil)[0].attributes.keys).contains("installID"), false, "no install id until the user shares")

    // The request: where it goes and what it carries.
    let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    let token = "pubTESTTOKENTESTTOKEN"
    let request = LogIntake.request(events, host: "browser-intake-datadoghq.com", clientToken: token, userAgent: "Ankey/1.4.0 (macOS 26.4)", requestID: id)
    expect(request.url?.absoluteString, "https://browser-intake-datadoghq.com/api/v2/logs?ddsource=ankey", "intake url")
    expect(request.httpMethod, "POST", "intake method")
    expect(request.value(forHTTPHeaderField: "DD-API-KEY"), token, "client token goes in DD-API-KEY")
    expect(request.value(forHTTPHeaderField: "Content-Type"), "application/json", "intake content type")
    expect(request.value(forHTTPHeaderField: "User-Agent"), "Ankey/1.4.0 (macOS 26.4)", "intake user agent")
    expect(request.value(forHTTPHeaderField: "DD-REQUEST-ID"), id.uuidString, "intake request id")
    expect(request.timeoutInterval, 10, "short timeout")
    let sent = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]] } ?? []
    expect(sent.count, 1, "body is an array of events")
    expect(sent.first?["ddsource"] as? String, "ankey", "body source")
    expect(sent.first?["service"] as? String, "ankey", "body service")
    expect(sent.first?["message"] as? String, "ankey.stats.day", "body message")
    expect(sent.first?["wordKept"] as? Int, 1, "body counters are numbers")
    let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
    expect(body.contains(token) || (request.url?.absoluteString.contains(token) ?? true), false, "token stays in the header only")
    expect(body.contains("com.secret.App"), false, "body holds no bundle id")
    let spoof = LogEvent(message: "m", attributes: ["service": .string("evil"), "ddsource": .string("evil"), "status": .string("evil")])
    let spoofed = (try? JSONSerialization.jsonObject(with: LogIntake.body([spoof])) as? [[String: Any]])?.first
    expect(spoofed?["service"] as? String, "ankey", "service cannot be overridden")
    expect(spoofed?["ddsource"] as? String, "ankey", "source cannot be overridden")
    expect(spoofed?["status"] as? String, "info", "status cannot be overridden")
    expect(LogIntake.body(events) == LogIntake.body(events), true, "same events give the same bytes")

    // Which days wait to be sent: finished days after the last upload.
    var span = StatsLog()
    for day in ["2026-10-13", "2026-10-14", "2026-10-15"] { span.record(.wordKept, on: day) }
    expect(span.pending(uploadedThrough: nil, today: "2026-10-15").ordered.map(\.day), ["2026-10-13", "2026-10-14"], "today waits")
    expect(span.pending(uploadedThrough: "2026-10-13", today: "2026-10-15").ordered.map(\.day), ["2026-10-14"], "sent days are not sent again")
    expect(span.pending(uploadedThrough: "2026-10-14", today: "2026-10-15").ordered.map(\.day), [], "nothing pending")
    expect(StatsUploadState(lastAttemptDay: "2026-10-15").isDue(on: "2026-10-15"), false, "one attempt a day")
    expect(StatsUploadState(lastAttemptDay: "2026-10-14").isDue(on: "2026-10-15"), true, "a new day is due")
    expect(StatsUploadState().isDue(on: "2026-10-15"), true, "first attempt is due")

    // The install id lives while sharing and starts fresh after.
    let first = StatsStore.installID(from: defaults)
    expect(StatsStore.installID(from: defaults), first, "install id is stable")
    StatsStore.forgetSharing(from: defaults)
    expect(StatsStore.installID(from: defaults) == first, false, "forgetting starts a new identity")
    StatsStore.forgetSharing(from: defaults)
}

final class RecordingSender: LogSender, @unchecked Sendable {
    var batches: [[LogEvent]] = []
    var fails = false
    struct Down: Error {}

    func send(_ events: [LogEvent]) async throws {
        if fails { throw Down() }
        batches.append(events)
    }
}

func runAsync(_ work: @escaping () async -> Void) {
    let done = DispatchSemaphore(value: 0)
    Task { await work(); done.signal() }
    done.wait()
}

func checkStatsUpload() {
    let suite = "ankey.tests.upload.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let day: TimeInterval = 86_400
    let today = Date(timeIntervalSince1970: 1_792_000_000)
    let sender = RecordingSender()

    func upload(_ now: Date) { runAsync { await StatsUploader.uploadIfDue(sender: sender, appVersion: "1.4.0", macOS: "26.4", now: now, defaults: defaults) } }

    var settings = Settings()
    settings.collectStats = true
    settings.save(to: defaults)
    StatsStore.record(.wordKept, now: today - day, defaults: defaults)

    upload(today)
    expect(sender.batches.count, 0, "collecting alone sends nothing")

    settings.shareStats = true
    settings.save(to: defaults)
    upload(today)
    expect(sender.batches.count, 1, "sharing sends the finished day")
    expect(sender.batches.first?.first?.attributes["day"], .string(StatsLog.dayKey(today - day)), "the day sent is yesterday")
    expect(sender.batches.first?.first?.attributes["installID"] != nil, true, "the batch carries the install id")
    upload(today)
    expect(sender.batches.count, 1, "no second send the same day")
    upload(today + day)
    expect(sender.batches.count, 1, "a sent day is not sent again")

    // A failure is silent, is not retried the same day, and tries again the next day.
    StatsStore.record(.wordKept, now: today + day, defaults: defaults)
    sender.fails = true
    upload(today + 2 * day)
    expect(sender.batches.count, 1, "failed send adds no batch")
    sender.fails = false
    upload(today + 2 * day)
    expect(sender.batches.count, 1, "no retry the same day")
    upload(today + 3 * day)
    expect(sender.batches.count, 2, "retry the next day")
    expect(sender.batches.last?.first?.attributes["day"], .string(StatsLog.dayKey(today + day)), "the retry sends the missed day")

    // Sharing off sends nothing, even on a new day.
    settings.shareStats = false
    settings.save(to: defaults)
    StatsStore.record(.wordKept, now: today + 3 * day, defaults: defaults)
    upload(today + 5 * day)
    expect(sender.batches.count, 2, "sharing off sends nothing")
}
func checkOnboarding() {
    let suite = "ankey.tests.onboarding.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    expect(Settings().onboardingSeen, false, "guide not seen by default")
    expect(Settings.load(from: defaults).onboardingSeen, false, "fresh defaults: not seen")
    Settings.markOnboardingSeen(in: defaults)
    expect(Settings.load(from: defaults).onboardingSeen, true, "marking is read back")
    expect(defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("onboarding") }.count, 1, "marking writes the one key")
    var settings = Settings.load(from: defaults)
    settings.onboardingSeen = false
    settings.save(to: defaults)
    expect(Settings.load(from: defaults).onboardingSeen, false, "flag round trip")

    expect(Onboarding.opensAtLaunch(seen: false, hadStoredValues: false), true, "fresh install opens the guide")
    expect(Onboarding.opensAtLaunch(seen: true, hadStoredValues: false), false, "seen once is enough")
    expect(Onboarding.opensAtLaunch(seen: false, hadStoredValues: true), false, "an update does not interrupt")
    expect(Onboarding.opensAtLaunch(seen: true, hadStoredValues: true), false, "seen update stays quiet")

    expect(InputSourceStatus(enabledFlags: []), .notListed, "no source listed")
    expect(InputSourceStatus(enabledFlags: [false]), .disabled, "listed and off")
    expect(InputSourceStatus(enabledFlags: [true]), .enabled, "listed and on")
    expect(InputSourceStatus(enabledFlags: [false, true]), .enabled, "any source on counts")
}


@main
struct TestRunner {
    static func main() {
        for (raw, want) in telex { check(raw, want) }
        checkSettings()
        checkAppRules()
        checkEncoding()
        checkStats()
        checkStatsUpload()
        checkOnboarding()
        checkTriggers()
        checkSlashTyping()
        checkCapture()
        checkFeedbackEvent()
        checkRelease()
        checkAnalyzeTiming()
        checkShorthand()
        checkAttested()
        checkBuiltInEnglish()
        checkContext()
        checkScore()
        checkAdjustStore()
        checkCorrection()
        checkToneUndo()
        checkLateCircumflex()
        checkCodeContext()
        checkRawRestore()
        checkDistantRepeat()
        checkSyllables()

        var session = Session()
        precondition(session.push("a") == .consumed)
        precondition(session.push("s") == .consumed)
        precondition(session.display(Settings()) == "á")
        precondition(session.push(" ") == .commit)
        precondition(session.pop())
        precondition(session.display(Settings()) == "a")
        precondition(session.pop())
        precondition(!session.pop())
        precondition(session.push(" ") == .pass)

        if failed != 0 {
            fputs("\(failed) failed\n", stderr)
            exit(1)
        }
        print("ok \(telex.count) words")
    }
}
