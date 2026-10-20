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
    ("lar", "lả"),
    ("ax", "ã"),
    ("aj", "ạ"),
    ("az", "az"),
    ("asz", "a"),
    ("ass", "as"),
    ("asss", "ass"),
    ("asf", "à"),
    ("aa", "â"),
    ("aaa", "aa"),
    ("aas", "ấ"),
    ("aw", "ă"),
    ("aww", "aw"),
    ("maws", "mắ"),
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
    expect(AppRule(stored: ["bundleID": "x", "unknownKey": "anything"]), AppRule(bundleID: "x"), "a stored rule with keys this version does not know still loads")
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

/// Telex keys that type `syllable` with the horn and breve key after the plain letters. `Engine.keys(for:)`
/// is the other order, every mark right after its letter.
func deferredKeys(_ syllable: String) -> String {
    var plain = "", tone = ""
    var horn = false
    for scalar in syllable.decomposedStringWithCanonicalMapping.unicodeScalars {
        switch scalar.value {
        case 0x0111: plain += "dd"
        case 0x0302: plain += String(plain.last!)
        case 0x0306, 0x031B: horn = true
        case 0x0301: tone = "s"
        case 0x0300: tone = "f"
        case 0x0309: tone = "r"
        case 0x0303: tone = "x"
        case 0x0323: tone = "j"
        default: plain += String(scalar)
        }
    }
    return plain + (horn ? "w" : "") + tone
}

/// Every attested syllable types out in both key orders, in either tone placement.
func checkSyllables() {
    func render(_ raw: String, _ style: ToneStyle) -> String {
        let settings = Settings(toneStyle: style)
        return Engine.render(raw, settings).precomposedStringWithCanonicalMapping
    }
    var english = 0
    for syllable in Syllables.all {
        for (mode, raw) in [("inline", Engine.keys(for: syllable)), ("deferred", deferredKeys(syllable))] {
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

/// Erasing a whole word and typing the same keys again says the engine chose the wrong language. The retype
/// shows the other one at once, and the word learns it when it is committed.
func checkCorrection() {
    let none = Settings()
    func type(_ session: inout Session, _ keys: String) {
        for ch in keys { _ = session.push(ch) }
    }
    func erase(_ session: inout Session) {
        while session.pop() {}
    }
    /// Commits with a space the way the controller does and reports what the word learned.
    func commit(_ session: inout Session, _ settings: Settings = Settings()) -> (text: String, learned: Correction?) {
        precondition(session.push(" ") == .commit)
        let text = session.finish(settings)
        return (text, session.learned)
    }
    func delete(_ session: inout Session, _ count: Int) {
        for _ in 0..<count { session.deleted() }
    }

    // Vietnamese was shown, so the retype turns English, and nothing changes before the last key.
    var session = Session()
    type(&session, "sex")
    expect(session.display(none), "s\u{1ebd}", "sex shows sẽ")
    expect(commit(&session).learned, nil, "the first typing learns nothing")
    session = Session()
    type(&session, "sex")
    erase(&session)
    type(&session, "se")
    expect(session.display(none), "se", "no flip before the last key")
    type(&session, "x")
    expect(session.display(none), "sex", "the retype shows English at once")
    let done = commit(&session)
    expect(done.text, "sex", "committed as typed")
    expect(done.learned, Correction(word: "sex", adjust: 2), "sex learned")
    expect(session.display(none), "", "nothing left")
    // English was shown, so the retype turns Vietnamese.
    session = Session()
    type(&session, "test")
    erase(&session)
    type(&session, "test")
    expect(session.display(none), "t\u{00e9}t", "test turns Vietnamese")
    expect(commit(&session).learned, Correction(word: "test", adjust: -2), "test learned")
    // A word Vietnamese wins by default is a known English word too.
    session = Session()
    type(&session, "cos")
    erase(&session)
    type(&session, "cos")
    expect(commit(&session).learned, Correction(word: "cos", adjust: 2), "cos learned")
    // A correction is undone from the other side, whatever the word before it.
    var taught = none
    taught.adjust = ["cos": 2]
    session = Session()
    type(&session, "cos")
    erase(&session)
    type(&session, "cos")
    expect(session.display(taught), "c\u{00f3}", "cos taught English turns back")
    expect(commit(&session, taught).learned, Correction(word: "cos", adjust: -2), "cos turned back")
    taught.adjust = ["cos": -2]
    expect(Engine.render("cos", taught, after: .english), "c\u{00f3}", "cos turned back after English too")
    // Case does not matter.
    session = Session()
    type(&session, "Sex")
    erase(&session)
    type(&session, "sex")
    expect(commit(&session).learned, Correction(word: "sex", adjust: 2), "case is ignored")

    // Backspace has other uses: none of these learns anything.
    session = Session()
    type(&session, "test")
    erase(&session)
    type(&session, "testing")
    expect(session.display(none), "testing", "a longer word is another word")
    expect(commit(&session).learned, nil, "testing learns nothing")
    session = Session()
    type(&session, "sex")
    erase(&session)
    type(&session, "sez")
    expect(commit(&session).learned, nil, "a typo fix is another word")
    session = Session()
    type(&session, "sex")
    erase(&session)
    type(&session, "sez")
    erase(&session)
    type(&session, "sex")
    expect(commit(&session).learned, nil, "a departed word is forgotten")
    session = Session()
    type(&session, "sex")
    erase(&session)
    type(&session, "sez")
    _ = session.pop()
    type(&session, "x")
    expect(commit(&session).learned, nil, "a word that left the erased keys stays gone")
    session = Session()
    type(&session, "sex")
    _ = session.pop()
    type(&session, "x")
    expect(commit(&session).learned, nil, "a partial delete")
    session = Session()
    type(&session, "sex")
    erase(&session)
    _ = session.push(" ")
    type(&session, "sex")
    expect(commit(&session).learned, nil, "another key between")
    session = Session()
    type(&session, "as")
    erase(&session)
    type(&session, "as")
    expect(commit(&session).learned, nil, "a Telex word of two letters")
    session = Session()
    type(&session, "hello")
    erase(&session)
    type(&session, "hello")
    expect(commit(&session).learned, nil, "one text only, nothing to choose")
    session = Session()
    type(&session, "sex")
    session.clear()
    type(&session, "sex")
    expect(commit(&session).learned, nil, "Esc is no erase")
    session = Session()
    type(&session, "sex")
    erase(&session)
    type(&session, "sex")
    _ = session.finishRaw()
    expect(session.learned, nil, "Esc after the retype learns nothing")
    var raw = none
    raw.restoreRaw = false
    session = Session()
    type(&session, "sex")
    erase(&session)
    type(&session, "sex")
    expect(commit(&session, raw).learned, nil, "raw restore off")
    // English needs evidence: a word the lists do not know as English never learns it.
    for word in ["banj", "hocj", "tooi"] {
        session = Session()
        type(&session, word)
        erase(&session)
        type(&session, word)
        expect(session.display(none), Engine.render(word), "\(word) keeps its reading")
        expect(commit(&session).learned, nil, "\(word) has no English side")
    }

    // A word the user committed and then deleted in the document.
    func committed(_ session: inout Session, _ keys: String) -> String {
        type(&session, keys)
        return commit(&session).text
    }
    session = Session()
    var text = committed(&session, "sex")
    expect(text, "s\u{1ebd}", "committed as sẽ")
    delete(&session, text.count + 1)
    type(&session, "sex")
    expect(session.display(none), "sex", "retyped after the commit")
    expect(commit(&session).learned, Correction(word: "sex", adjust: 2), "learned after the commit")
    session = Session()
    text = committed(&session, "sex")
    delete(&session, text.count)
    type(&session, "sex")
    expect(commit(&session).learned, nil, "the boundary key is still there")
    session = Session()
    text = committed(&session, "sex")
    delete(&session, text.count + 2)
    type(&session, "sex")
    expect(commit(&session).learned, nil, "one delete too many")
    session = Session()
    text = committed(&session, "sex")
    delete(&session, 1)
    _ = session.push("a")
    delete(&session, text.count)
    type(&session, "sex")
    expect(commit(&session).learned, nil, "typing in between")
    session = Session()
    text = committed(&session, "sex")
    delete(&session, text.count + 1)
    session.forgetContext()
    type(&session, "sex")
    expect(commit(&session).learned, nil, "the caret moved")
}

/// A tone key typed twice undoes the tone. The keys stay whole unless the undone text is a syllable, so English
/// words with a double letter are never cut. A mark key typed again drops the extra key.
func checkSwap() {
    let none = Settings()
    func typed(_ keys: String) -> Session {
        var session = Session()
        for ch in keys { _ = session.push(ch) }
        return session
    }

    // A word that stayed as typed shows its Vietnamese reading, and a second swap goes back.
    var session = typed("test")
    expect(session.display(none), "test", "test stays as typed")
    expect(session.swap(none), .vietnamese, "swap names the language now shown")
    expect(session.display(none), "t\u{e9}t", "swap shows tét")
    expect(session.swap(none), .english, "swap again names English")
    expect(session.display(none), "test", "swap again goes back")

    // A converted word shows its typed keys.
    session = typed("cos")
    expect(session.display(none), "c\u{f3}", "cos shows có")
    expect(session.swap(none), .english, "swap turns có into the typed keys")
    expect(session.display(none), "cos", "swap shows cos")

    // Keys with one reading change nothing, and a second swap does not remember the first.
    session = typed("hello")
    expect(session.swap(none), nil, "hello has one reading")
    expect(session.display(none), "hello", "hello stays")
    session = Session()
    expect(session.swap(none), nil, "nothing typed, nothing to swap")

    // Any change to the keys takes the swap back.
    session = typed("test")
    _ = session.swap(none)
    _ = session.push("s")
    expect(session.display(none), Engine.render("tests", none), "a key after the swap reads the word afresh")
    session = typed("test")
    _ = session.swap(none)
    _ = session.pop()
    expect(session.display(none), Engine.render("tes", none), "backspace after the swap reads the word afresh")

    // The committed text is the swapped one, and the next word follows its language.
    session = typed("test")
    _ = session.swap(none)
    expect(session.push(" "), .commit, "space commits the swapped word")
    expect(session.finish(none), "t\u{e9}t", "the swapped text is committed")
    expect(session.learned, nil, "a swap learns nothing")
    for ch in "own" { _ = session.push(ch) }
    expect(session.display(none), "\u{1a1}n", "the next word follows Vietnamese")
}

func checkDoubledKey() {
    for word in [
        "boss", "pass", "class", "mass", "less", "loss", "miss", "off", "carry", "marry", "buff", "lass", "diss", "muss",
        "harass", "hiss", "lass", "iff", "address", "assert", "assertEqual", "assist", "error", "staff",
        "success", "process", "message", "coffee", "banjj", "hocjj",
    ] { check(word, word) }
    for (typed, want) in [("tooo", "too"), ("seee", "see"), ("saww", "saw")] { check(typed, want) }
}

func checkShortDevWords() {
    let s = Settings()
    for word in ["ex", "ix", "ox", "er", "ar", "aws", "efs", "orm", "AWS", "EFS", "ORM"] {
        expect(Engine.render(word, s, after: nil), word, "\(word) stays as typed")
    }
    expect(Engine.render("os", s, after: nil), "\u{00f3}", "os without context")
    expect(Engine.render("os", s, after: .english), "os", "os after English")
    expect(Engine.render("es", s, after: .english), "es", "es after English")
    // A digit right after the letters ties them to it; a space does not.
    func commit(_ keys: String, _ boundary: Character) -> String {
        var session = Session()
        for ch in keys { _ = session.push(ch) }
        precondition(session.push(boundary) == .commit)
        return session.finish(s)
    }
    expect(commit("arm", "6"), "arm", "arm64")
    expect(commit("arm", " "), "\u{1ea3}m", "arm then a space")
    expect(commit("cams", "2"), "cams", "cams2")
}

func checkSuggest() {
    func index(_ lines: String) -> PhraseIndex {
        guard let index = PhraseIndex(data: PhraseIndex.build(lines: lines.split(separator: "\n"))) else {
            fatalError("the index it built does not read back")
        }
        return index
    }
    func rest(_ typed: String, _ index: PhraseIndex, _ style: ToneStyle = .modern) -> String? {
        Suggest.completion(after: typed.split(separator: " ").map(String.init), style: style, in: index)?.text
    }

    // What every phrase through the typed words agrees on, up to where they split or one ends.
    let small = index("a b c d e\na b c d f\nx y z w\nx y z\np q r s t\n# a comment")
    expect(rest("a", small), "b c d", "the common stretch before a split")
    expect(rest("a b c d", small), nil, "the phrases split right after")
    expect(rest("x y", small), "z", "the rest stops where a phrase ends")
    expect(rest("x y z", small), nil, "the typed words are a phrase themselves")
    expect(rest("p q", small), "r s t", "several syllables left")
    expect(rest("q r s", small), nil, "no phrase starts there")
    expect(rest("z a b c", small), "d", "the longest run that starts a phrase decides")
    expect(rest("a b c d e", small), nil, "the phrase is done")
    expect(rest("a b unknown", small), nil, "a syllable no phrase has")
    expect(rest("", small), nil, "no word typed")

    // Case and tone placement compare equal; the rest takes the user's placement.
    let tones = index("xin thế hoà bình giới")
    expect(rest("Xin Thế Hòa", tones), "bình giới", "capitals and placement are no difference")
    let placed = index("x y z hoà bình")
    expect(rest("x y z", placed, .modern), "hoà bình", "modern placement")
    expect(rest("x y z", placed, .classic), "hòa bình", "classic placement")

    // A prefix whose other continuations were too rare to list ends in a stop, so it offers nothing.
    let stop = index("a b c d\na b …")
    expect(rest("a b", stop), nil, "a stop keeps the words from suggesting the one listed way")
    expect(rest("a b c", stop), "d", "the listed way still completes")

    // The real list: common compounds, found by counting Vietnamese text.
    guard let text = try? String(contentsOfFile: "Resources/phrases.txt", encoding: .utf8) else {
        failed += 1
        fputs("FAIL Resources/phrases.txt cannot be read\n", stderr)
        return
    }
    let real = index(text)
    expect(rest("ung", real), "thư", "a compound")
    expect(rest("không có thời", real), "gian", "a common phrase")
    expect(rest("cuộc chiến thương", real), "mại", "the end of a word")
    expect(rest("thành phố hồ chí", real), "minh", "a name")
    expect(rest("tôi đang ăn", real), nil, "no certain way on")

    // A session offers the rest only after words ended by spaces, and a break takes it away.
    let phrases = index("lỡ vận sa cơ")
    var session = Session()
    let settings = Settings()
    func word(_ keys: String, _ boundary: Character = " ") {
        for ch in keys { _ = session.push(ch) }
        precondition(session.push(boundary) == .commit)
        _ = session.finish(settings)
    }
    word("lowx")
    expect(session.suggestion(settings, in: phrases)?.text, "vận sa cơ", "after one word")
    word("vaajn")
    expect(session.suggestion(settings, in: phrases)?.text, "sa cơ", "after two words")
    word("sa")
    expect(session.suggestion(settings, in: phrases)?.text, "cơ", "after three words")
    _ = session.push("c")
    expect(session.suggestion(settings, in: phrases)?.text, "cơ", "a letter typed keeps the run")
    _ = session.pop()
    session.deleted()
    expect(session.suggestion(settings, in: phrases)?.text, nil, "a backspace to the app ends it")
    word("lowx"); word("vaajn"); word("sa", ",")
    expect(session.suggestion(settings, in: phrases)?.text, nil, "a comma ends it")
    word("lowx"); word("vaajn"); word("sa")
    _ = session.push(" ")
    expect(session.suggestion(settings, in: phrases)?.text, nil, "a second space ends it")
    // The run keeps only the words Suggest reads, however long the text goes without a break.
    session = Session()
    for _ in 0..<40 { word("ba") }
    word("lowx"); word("vaajn"); word("sa")
    expect(session.suggestion(settings, in: phrases)?.text, "cơ", "after a long run")
    let kept = Mirror(reflecting: session).children.first { $0.label == "phrase" }?.value as? [String]
    expect(kept?.count, Suggest.maxWords, "the run is capped")
    word("lowx"); word("vaajn"); word("sa")
    session.accepted()
    expect(session.suggestion(settings, in: phrases)?.text, nil, "accepting starts a new run")
}

func checkResourceUsage() {
    func sample(cpu: Double, at: Double) -> ResourceSample {
        ResourceSample(footprintBytes: 0, peakFootprintBytes: 0, cpuSeconds: cpu, threads: 1, uptime: 0, at: at)
    }
    expect(ResourceUsage.cpuPercent(from: sample(cpu: 1, at: 10), to: sample(cpu: 1.5, at: 12)), 25, "half a second of CPU in two")
    expect(ResourceUsage.cpuPercent(from: sample(cpu: 1, at: 10), to: sample(cpu: 3, at: 11)), 200, "two cores busy")
    expect(ResourceUsage.cpuPercent(from: sample(cpu: 1, at: 10), to: sample(cpu: 1, at: 10)), 0, "no time passed")
    expect(ResourceUsage.size(512 * 1024), "512 KB", "kilobytes")
    expect(ResourceUsage.size(26_500_000), "25,3 MB", "megabytes with a comma")
    expect(ResourceUsage.size(1_288_490_189), "1,2 GB", "gigabytes")
    expect(ResourceUsage.percent(0.34), "0,3%", "a decimal under ten")
    expect(ResourceUsage.percent(12.6), "13%", "whole above ten")
    expect(ResourceUsage.duration(45), "45 giây", "seconds")
    expect(ResourceUsage.duration(12 * 60 + 5), "12 phút", "minutes")
    expect(ResourceUsage.duration(3600 + 12 * 60), "1 giờ 12 phút", "hours")
    expect(ResourceUsage.duration(2 * 86_400 + 3 * 3600 + 59), "2 ngày 3 giờ", "days")
}

func checkPersonalPhrases() {
    /// Types `sentence` the way a Session reports it: each word after the ones before it, as a run.
    func learn(_ sentence: String, times: Int = 1, day: Int = 0, into phrases: inout PersonalPhrases) {
        let words = sentence.split(separator: " ").map(String.init)
        for _ in 0..<times {
            for end in 1..<words.count {
                phrases.observe(context: Array(words[..<end]), word: words[end], covered: false, today: day)
            }
        }
    }
    func rest(_ typed: String, _ phrases: PersonalPhrases, day: Int = 0) -> String? {
        phrases.certain(after: typed.split(separator: " ").map(String.init), today: day)?.joined(separator: " ")
    }

    // A pair is learned from its second sighting and suggested from its third.
    var phrases = PersonalPhrases()
    learn("công ty abc", times: 1, into: &phrases)
    expect(phrases.isEmpty, true, "one sighting is not stored")
    learn("công ty abc", times: 1, into: &phrases)
    expect(rest("công ty", phrases), nil, "two sightings are not enough")
    learn("công ty abc", times: 1, into: &phrases)
    expect(rest("công ty", phrases), "abc", "three sightings suggest")
    expect(rest("Công Ty", phrases), "abc", "capitals compare equal")
    expect(rest("ty", phrases), "abc", "a shorter prefix learned too")

    // Two ways on, neither with most of the occurrences, offer nothing.
    phrases = PersonalPhrases()
    learn("dự án x", times: 3, into: &phrases)
    learn("dự án y", times: 3, into: &phrases)
    expect(rest("dự án", phrases), nil, "an even split")

    // What the shared list predicts is not stored; numbers and long tokens are not learned.
    phrases = PersonalPhrases()
    for _ in 0..<5 { phrases.observe(context: ["xã", "hội"], word: "chủ", covered: true, today: 0) }
    expect(phrases.isEmpty, true, "covered by the shared list")
    for _ in 0..<5 { phrases.observe(context: ["mã", "số"], word: "a1b2", covered: false, today: 0) }
    expect(phrases.isEmpty, true, "a token with digits")

    // A phrase goes on as far as the user's text agrees.
    phrases = PersonalPhrases()
    learn("công ty abc ltd", times: 3, into: &phrases)
    expect(rest("công ty", phrases), "abc ltd", "a chain")

    // The table never passes its cap, however much is typed.
    phrases = PersonalPhrases()
    for i in 0..<30_000 {
        for _ in 0..<2 { phrases.observe(context: ["w\(i % 997)x", "k"], word: "n\(i)a", covered: false, today: 0) }
    }
    expect(phrases.nodes.count <= PersonalPhrases.maxNodes, true, "the cap holds")

    // What was used often and lately outlasts what was not.
    phrases = PersonalPhrases()
    learn("tên riêng hay gặp", times: 40, day: 100, into: &phrases)
    for i in 0..<PersonalPhrases.maxNodes + 2000 {
        for _ in 0..<2 { phrases.observe(context: ["a\(i)b"], word: "c", covered: false, today: 100) }
    }
    expect(rest("tên riêng", phrases, day: 100), "hay gặp", "the frequent phrase survived the eviction")

    // Habits change: the old count fades, and the new phrase takes over.
    phrases = PersonalPhrases()
    learn("gửi anh a", times: 12, day: 0, into: &phrases)
    expect(rest("gửi anh", phrases, day: 0), "a", "the first habit")
    expect(rest("gửi anh", phrases, day: 400), nil, "unused for over a year, it is forgotten")
    learn("gửi anh b", times: 15, day: 100, into: &phrases)
    expect(rest("gửi anh", phrases, day: 100), "b", "the new habit wins")

    // A habit however well learned is relearned in tens of uses, not in as many as it took to learn it.
    var settled = PersonalPhrases()
    learn("gửi anh a", times: 500, into: &settled)
    expect(rest("gửi anh", settled), "a", "a settled habit")
    var uses = 0
    while rest("gửi anh", settled) != "b", uses < 300 {
        learn("gửi anh b", times: 1, into: &settled)
        uses += 1
    }
    expect(uses <= 80, true, "relearned within 80 uses (took \(uses))")
    var stops = 0
    var leaving = PersonalPhrases()
    learn("gửi anh a", times: 500, into: &leaving)
    while rest("gửi anh", leaving) == "a", stops < 300 {
        learn("gửi anh b", times: 1, into: &leaving)
        stops += 1
    }
    expect(stops <= 15, true, "the old suggestion stops within 15 uses of the new (took \(stops))")

    // It survives being written to disk, and the table of first sightings stays bytes, not a list of numbers.
    phrases = PersonalPhrases()
    learn("công ty abc ltd", times: 3, into: &phrases)
    guard let data = try? JSONEncoder().encode(phrases), let back = try? JSONDecoder().decode(PersonalPhrases.self, from: data) else {
        failed += 1
        fputs("FAIL personal phrases do not round-trip\n", stderr)
        return
    }
    expect(back, phrases, "a round trip changes nothing")
    expect(data.count < 400_000, true, "a small table is a small file")

    // Forgetting one phrase leaves the rest.
    var forgotten = back
    forgotten.forget(prefix: "công ty", word: "abc")
    expect(rest("công ty", forgotten), nil, "forgotten")
    expect(rest("ty abc", forgotten), "ltd", "the rest stays")

    // Personal phrases come before the shared list.
    let shared = PhraseIndex(data: PhraseIndex.build(lines: ["công ty xyz kia"]))!
    expect(Suggest.completion(after: ["công", "ty"], style: .modern, in: shared), Suggestion(text: "xyz kia", personal: false), "the shared list alone")
    expect(Suggest.completion(after: ["công", "ty"], style: .modern, in: shared, personal: phrases), Suggestion(text: "abc ltd", personal: true), "personal first, and it says so")
}

func checkLanguageHabits() {
    var habits = LanguageHabits()
    habits.asOf = 0
    func teach(_ word: String, _ language: Language, _ times: Int, day: Int = 0) {
        for _ in 0..<times { habits.observe(after: word, language: language, weight: 1, today: day) }
    }
    expect(habits.lean(after: "dùng"), nil, "nothing learned yet")
    teach("dùng", .english, 7)
    expect(habits.lean(after: "dùng"), nil, "seven samples are too few")
    teach("dùng", .english, 1)
    expect(habits.lean(after: "dùng"), .english, "eight one-sided samples lean")
    expect(habits.lean(after: "Dùng"), .english, "capitals compare equal")
    teach("tôi", .vietnamese, 20)
    expect(habits.lean(after: "tôi"), .vietnamese, "the other way")
    teach("rồi", .vietnamese, 9)
    teach("rồi", .english, 3)
    expect(habits.lean(after: "rồi"), nil, "a word followed by both is not decided (75%)")
    expect(habits.lean(after: nil), nil, "no word before")

    // A word chosen by hand counts for several samples.
    habits.observe(after: "cài", language: .english, weight: LanguageHabits.chosenWeight, today: 0)
    habits.observe(after: "cài", language: .english, weight: LanguageHabits.chosenWeight, today: 0)
    expect(habits.lean(after: "cài"), .english, "two chosen words are eight samples")

    // The habit changes with the user, and what is not seen fades.
    habits.asOf = 400
    expect(habits.lean(after: "dùng"), nil, "unused for over a year, it is forgotten")
    habits.asOf = 0
    var changing = LanguageHabits()
    for _ in 0..<40 { changing.observe(after: "x", language: .english, weight: 1, today: 0) }
    for _ in 0..<100 { changing.observe(after: "x", language: .vietnamese, weight: 1, today: 120) }
    changing.asOf = 120
    expect(changing.lean(after: "x"), .vietnamese, "the new habit wins")

    // A habit however well learned is relearned in tens of words.
    var settled = LanguageHabits()
    for _ in 0..<500 { settled.observe(after: "dùng", language: .english, weight: 1, today: 0) }
    var words = 0
    while settled.lean(after: "dùng") != .vietnamese, words < 400 {
        settled.observe(after: "dùng", language: .vietnamese, weight: 1, today: 0)
        words += 1
    }
    expect(words <= 120, true, "relearned within 120 words (took \(words))")

    // The table never passes its cap, and what is one-sided and frequent outlasts the noise.
    var full = LanguageHabits()
    for _ in 0..<30 { full.observe(after: "giữ", language: .english, weight: 1, today: 0) }
    for i in 0..<(LanguageHabits.maxNodes + 3000) {
        full.observe(after: "w" + String(UnicodeScalar(UInt8(97 + i % 26))) + String(UnicodeScalar(UInt8(97 + (i / 26) % 26))) + String(UnicodeScalar(UInt8(97 + (i / 676) % 26))) + String(UnicodeScalar(UInt8(97 + (i / 17576) % 26))), language: .vietnamese, weight: 1, today: 0)
    }
    expect(full.nodes.count <= LanguageHabits.maxNodes, true, "the cap holds")
    expect(full.lean(after: "giữ"), .english, "the frequent one-sided word survived")

    // It survives being written to disk, and a word can be forgotten.
    guard let data = try? JSONEncoder().encode(habits), let back = try? JSONDecoder().decode(LanguageHabits.self, from: data) else {
        failed += 1
        fputs("FAIL habits do not round-trip\n", stderr)
        return
    }
    expect(back, habits, "a round trip changes nothing")
    var forgotten = back
    forgotten.forget("dùng")
    expect(forgotten.lean(after: "dùng"), nil, "forgotten")

    // The engine: the habit settles a word that could be either, and never turns English everywhere into Vietnamese.
    var settings = Settings()
    settings.habits = habits
    expect(Engine.analyze("as", settings, after: .vietnamese, habit: .english).text, "as", "as after a word English follows")
    expect(Engine.analyze("as", settings, after: .vietnamese, habit: .vietnamese).text, "\u{00e1}", "á after a word Vietnamese follows")
    expect(Engine.analyze("test", settings, after: .vietnamese, habit: .vietnamese).text, "test", "test stays English whatever follows")
    expect(Engine.analyze("as", settings, after: .english, habit: .vietnamese).text, "\u{00e1}", "the habit takes the context bonus back")
    expect(Engine.analyze("cos", settings, after: .english, habit: .english).text, "cos", "a word the Vietnamese wins by default turns with both")
    expect(Engine.analyze("cos", settings, after: .vietnamese, habit: .english).text, "c\u{00f3}", "and not with the habit alone")

    // A session reads the habit of the word before, and reports what it learned.
    func type(_ session: inout Session, _ keys: String, _ boundary: Character = " ") -> String {
        for ch in keys { _ = session.push(ch) }
        precondition(session.push(boundary) == .commit)
        return session.finish(settings)
    }
    var session = Session()
    _ = type(&session, "tooi")
    expect(session.observed == nil, true, "the first word has no word before it")
    _ = type(&session, "dungf")
    expect(session.observed?.previous, "tôi", "the word before")
    expect(session.observed?.language, .vietnamese, "a Vietnamese word, never in doubt")
    expect(session.observed?.weight, 1, "counted once")
    _ = type(&session, "hello")
    expect(session.observed?.language, .english, "an English word, never in doubt")
    _ = type(&session, "test")
    expect(session.observed == nil, true, "a word the lists know says nothing: its language came from the same score")
    // The word after one the user always follows with English.
    var learned = Settings()
    var trained = LanguageHabits()
    for _ in 0..<10 { trained.observe(after: "cài", language: .english, weight: 1, today: 0) }
    trained.asOf = 0
    learned.habits = trained
    session = Session()
    for ch in "caif " { _ = session.push(ch) }
    _ = session.finish(learned)
    for ch in "as" { _ = session.push(ch) }
    expect(session.display(learned), "as", "after cài, as is English")
    expect(session.display(Settings()), "\u{00e1}", "without the habit it is á")
    // Esc is a choice, and a strong one.
    session = Session()
    for ch in "caif " { _ = session.push(ch) }
    _ = session.finish(settings)
    for ch in "as" { _ = session.push(ch) }
    _ = session.finishRaw()
    expect(session.observed?.previous, "cài", "Esc: the word before")
    expect(session.observed?.language, .english, "Esc: English")
    expect(session.observed?.weight, LanguageHabits.chosenWeight, "Esc: a chosen word")
}

func checkToneUndo() {
    let s = Settings()
    // The keys before the repeat showed Vietnamese, so the repeat undoes the tone.
    for (typed, want) in [("ass", "as"), ("coss", "cos"), ("sexx", "sex"), ("taxx", "tax"), ("carr", "car"), ("barr", "bar"), ("ASS", "AS")] {
        expect(Engine.render(typed, s), want, "\(typed) undoes the tone")
    }
    for (typed, want) in [("oss", "os"), ("ess", "es"), ("err", "err")] {
        expect(Engine.render(typed, s), want, "\(typed) undoes the tone or stays")
    }
    // The third press gives the doubled letters; a fourth is not a Telex key anymore.
    for (typed, want) in [("asss", "ass"), ("cosss", "coss"), ("assss", "assss"), ("bosss", "bosss")] {
        expect(Engine.render(typed, s), want, "\(typed) third press")
    }
    expect(Engine.render("asss", s, after: .english), "asss", "asss after English")
    // After an English word `as` already shows as typed, so the second key is a letter.
    expect(Engine.render("ass", s, after: .english), "ass", "ass after English")
    // A longer word reads from the start again.
    expect(Engine.render("assert", s), "assert", "assert")
    expect(Engine.render("ass", Settings(restoreRaw: false)), "as", "ass keeps the Telex undo with restoreRaw off")
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
    var configured = Settings()
    configured.appRules = [AppRule(bundleID: "com.secret.App")]
    let payload = StatsPayload(appVersion: "1.4.0", macOS: "26.4", settings: configured, log: sample)
    let events = payload.events(installID: "11111111-2222-3333-4444-555555555555")
    expect(events.count, 1, "one event per day")
    expect(Set(events[0].attributes.keys), [
        "appVersion", "macOS", "toneStyle", "appRuleCount", "day", "installID",
        "wordChanged", "wordKept", "escRestoredRaw", "directFallback",
        "correctionToEnglish", "correctionToVietnamese", "flipToEnglish", "flipToVietnamese", "habitToEnglish", "habitToVietnamese",
        "sharedSuggestionShown", "sharedSuggestionAccepted", "sharedSuggestionDismissed",
        "personalSuggestionShown", "personalSuggestionAccepted", "personalSuggestionDismissed",
    ], "payload attributes are the allowlist")
    let strings = events[0].attributes.values.compactMap { value -> String? in
        if case .string(let text) = value { return text }
        return nil
    }
    expect(Set(strings), ["1.4.0", "26.4", "modern", "2026-10-15", "11111111-2222-3333-4444-555555555555"], "payload strings are version, settings, day and install id only")
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


/// A document edited the way an `IMKTextInput` client is. `completion` makes it an address bar: once the text
/// starts a known address, the rest is added and selected, the way an omnibox shows its inline completion
/// (`omnibox_view_views.cc`, `OnInlineAutocompleteTextMaybeChanged`).
private final class Document {
    let text = NSMutableString()
    var selection = NSRange(location: 0, length: 0)
    var completion: String?

    func insert(_ string: String, replacing range: NSRange?) {
        let range = range ?? selection
        text.replaceCharacters(in: range, with: string)
        selection = NSRange(location: range.location + (string as NSString).length, length: 0)
        complete()
    }

    func deleteBackward() {
        if selection.length > 0 {
            text.deleteCharacters(in: selection)
            selection = NSRange(location: selection.location, length: 0)
            return
        }
        guard selection.location > 0 else { return }
        text.deleteCharacters(in: NSRange(location: selection.location - 1, length: 1))
        selection = NSRange(location: selection.location - 1, length: 0)
    }

    private func complete() {
        guard let completion, text.length > 0, selection.location == text.length,
              completion.hasPrefix(text as String), completion != text as String else { return }
        let typed = text.length
        text.setString(completion)
        selection = NSRange(location: typed, length: text.length - typed)
    }
}

/// What the app does around the keys Ankey handles. AppKit stops at a key the input method took, and so does the
/// omnibox view (`bridged_content_view.mm`). Chromium web content (`render_widget_host_view_cocoa.mm`) commits a
/// replacement at once, but forwards the key event to its renderer anyway, and Blink (`editing_behavior.cc`,
/// `VKEY_BACK`) runs its own delete for backspace; only marked text or an insertion of two or more characters at
/// the caret stops that.
private enum App: String {
    case appKit, chromium
}

private let backspace: Character = "\u{8}"

/// Mirrors the direct-insertion branches of `AnkeyInputController`: a letter shows the rendered word, a boundary
/// commits it, backspace is left to the app and `Session.erased` follows.
private struct Typist {
    var session = Session()
    var shown = DirectWord()
    let settings = Settings()

    /// True when Ankey took the key. `edits` are the `insertText` calls it made.
    mutating func handle(_ key: Character, selection: NSRange, _ edits: inout [DirectWord.Edit]) -> Bool {
        if key == backspace {
            guard let left = shown.erased(selection: selection) else { return false }
            if !session.erased(leaving: left) { session.deleted() }
            return false
        }
        switch session.push(key) {
        case .consumed:
            if let (edit, _) = shown.show(session.display(settings), selection: selection) {
                edits.append(edit)
            }
            return true
        case .commit:
            if let (edit, _) = shown.show(session.finish(settings), selection: selection) {
                edits.append(edit)
            }
            shown = DirectWord()
            return false
        case .pass:
            return false
        case .flush, .cheat:
            preconditionFailure("not typed here")
        }
    }
}

/// One key as the app processes it around the input method.
private func keyDown(_ key: Character, _ app: App, _ document: Document, _ typist: inout Typist) {
    var edits: [DirectWord.Edit] = []
    let taken = typist.handle(key, selection: document.selection, &edits)
    var atCaret = ""
    for edit in edits {
        switch edit {
        case .replace(let string, let location, let length):
            document.insert(string, replacing: NSRange(location: location, length: length))
        case .insert(let string):
            if app == .chromium { atCaret += string } else { document.insert(string, replacing: nil) }
        }
    }
    switch app {
    case .appKit:
        guard !taken else { return }
        if key == backspace { document.deleteBackward() } else { document.insert(String(key), replacing: nil) }
    case .chromium:
        if atCaret.count > 1 {
            document.insert(atCaret, replacing: nil)
            return
        }
        if key == backspace { document.deleteBackward() }
        if atCaret.count == 1 {
            document.insert(atCaret, replacing: nil)
        } else if !taken, key != backspace {
            document.insert(String(key), replacing: nil)
        }
    }
}

private func typed(_ keys: String, in app: App, completing completion: String? = nil) -> String {
    let document = Document()
    document.completion = completion
    var typist = Typist()
    for key in keys { keyDown(key, app, document, &typist) }
    return document.text as String
}

private func caret(_ location: Int) -> NSRange {
    NSRange(location: location, length: 0)
}

/// Direct insertion: the edits that show the word, and backspace left to the app.
func checkDirect() {
    for (text, keys) in [
        ("ti\u{1ebf}", "tiees"), ("\u{0110}\u{00e0}", "DDaf"), ("\u{01b0}\u{1edb}t", "uwowts"),
        ("hello", "hello"), ("tieetc", "tieetc"), ("", ""),
    ] {
        expect(Engine.keys(for: text), keys, "keys for \(text.debugDescription)")
    }

    var word = DirectWord()
    expect(word.show("t", selection: caret(5))?.edit, .insert("t"), "the first letter goes in at the caret")
    expect(word.show("ti", selection: caret(6))?.edit, .replace("ti", location: 5, length: 1), "the next key replaces the word")
    expect(word.show("ti", selection: caret(7)) == nil, true, "the same text is no edit")
    let lost = word.show("ti\u{00ea}", selection: nil)
    expect(lost?.edit, .insert("ti\u{00ea}"), "an unknown selection inserts")
    expect(lost?.found, false, "and reports the word lost")
    expect(word.show("ti\u{1ebf}", selection: caret(2))?.found, false, "a caret before the word reports it lost")
    expect(word.text, "ti\u{1ebf}", "the word is what was inserted last")
    expect(word.erased(selection: caret(3)), "ti", "backspace takes the last letter out")
    expect(word.erased(selection: nil), "t", "and the next, selection or not")
    expect(word.erased(selection: caret(1)), "", "down to nothing")
    expect(word.erased(selection: caret(0)), "", "and stays there")

    // An address bar selects its inline completion right after the word.
    var address = DirectWord()
    _ = address.show("t", selection: caret(0))
    let completed = NSRange(location: 1, length: 19)
    expect(address.show("to", selection: completed)?.edit, .replace("to", location: 0, length: 20), "the key replaces the word and the selected completion")
    expect(address.erased(selection: NSRange(location: 2, length: 18)) == nil, true, "backspace with a selection leaves the word whole")
    expect(address.text, "to", "still the whole word")
    expect(address.erased(selection: caret(2)), "t", "and takes a letter with none")

    let settings = Settings()
    var session = Session()
    for key in "tieets" { _ = session.push(key) }
    expect(session.display(settings), "ti\u{1ebf}t", "ti\u{1ebf}t typed")
    expect(session.erased(leaving: "ti\u{1ebf}"), true, "the app took the t out")
    expect(session.display(settings), "ti\u{1ebf}", "the keys now type what is left")
    _ = session.push("c")
    expect(session.display(settings), "ti\u{1ebf}c", "the next key continues the word on screen")
    for left in ["ti\u{1ebf}", "ti", "t", ""] { expect(session.erased(leaving: left), true, "erased to \(left.debugDescription)") }
    expect(session.isComposing, false, "nothing left to compose")
    expect(session.erased(leaving: ""), false, "a backspace with no word is the app's own")
    session = Session()
    for key in "///b" { _ = session.push(key) }
    expect(session.erased(leaving: "///"), true, "a held code loses its last key")
    expect(session.display(settings), "///", "and shows what is left")
    // A word erased on screen and typed again learns, the same as one erased key by key.
    session = Session()
    for key in "sex" { _ = session.push(key) }
    expect(session.display(settings), "s\u{1ebd}", "s\u{1ebd} shown")
    for left in ["s", ""] { _ = session.erased(leaving: left) }
    for key in "sex" { _ = session.push(key) }
    expect(session.display(settings), "sex", "erased on screen and typed again shows English")
    _ = session.push(" ")
    _ = session.finish(settings)
    expect(session.learned, Correction(word: "sex", adjust: 2), "and learns it")

    for app in [App.appKit, .chromium] {
        for (keys, want, label) in [
            ("aam tieets\(backspace)c", "\u{00e2}m ti\u{1ebf}c", "the t goes and c continues the word"),
            ("tieecs\(backspace)\(backspace)", "ti", "two backspaces take two letters off the screen"),
            ("aam tieecs\(backspace)\(backspace)", "\u{00e2}m ti", "and leave the word before alone"),
            ("tieets\(backspace)\(backspace)\(backspace)\(backspace)\(backspace)", "", "more backspaces than letters"),
            ("aam \(backspace)\(backspace)tieets", "\u{00e2}ti\u{1ebf}t", "backspaces into a committed word"),
            ("sex\(backspace)\(backspace)sex ", "sex ", "a word erased on screen and typed again"),
        ] {
            expect(typed(keys, in: app), want, "\(app.rawValue): \(label)")
        }
    }
    for (keys, want, label) in [
        ("to", "to", "the key replaces the selected completion with the word"),
        ("tr", "translate.google.com", "an address still typed keeps completing"),
        ("t\(backspace)ooi", "t\u{00f4}i", "backspace takes the completion out and the word goes on"),
    ] {
        expect(typed(keys, in: .appKit, completing: "translate.google.com"), want, "address bar: \(label)")
    }
}

@main
struct TestRunner {
    static func main() {
        for (raw, want) in telex { check(raw, want) }
        checkSettings()
        checkAppRules()
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
        checkSwap()
        checkDirect()
        checkDoubledKey()
        checkToneUndo()
        checkResourceUsage()
        checkPersonalPhrases()
        checkLanguageHabits()
        checkSuggest()
        checkShortDevWords()
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
