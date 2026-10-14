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

func checkMacroStorage() {
    let suite = "ankey.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    // Never saved: defaults.
    expect(Settings.load(from: defaults).macros, [], "macros default")
    expect(Settings.load(from: defaults).shorthand, ["\u{0111}c"], "shorthand default")
    expect(Settings.load(from: defaults).appRules, [], "appRules default")

    // Round trip.
    var settings = Settings()
    settings.macros = [
        Macro(shortcut: "vn", text: "Vi\u{1ec7}t Nam"),
        Macro(shortcut: "ko", text: "kh\u{00f4}ng"),
    ]
    settings.shorthand = ["\u{0111}t"]
    settings.appRules = [
        AppRule(bundleID: "com.apple.Terminal", enabled: false),
        AppRule(bundleID: "com.tdesktop.Telegram", insertion: .direct),
    ]
    settings.save(to: defaults)
    expect(Settings.load(from: defaults), settings, "round trip")

    // Cleanup on load: trim + lowercase, drop duplicates (first wins), non-letters,
    // empty shortcut, empty text. An empty-text row does not reserve its shortcut.
    settings.macros = [
        Macro(shortcut: " VN ", text: "Vi\u{1ec7}t Nam"),
        Macro(shortcut: "vn", text: "dup"),
        Macro(shortcut: "VN", text: "dup upper"),
        Macro(shortcut: "x1", text: "digit"),
        Macro(shortcut: "", text: "none"),
        Macro(shortcut: "ok", text: ""),
        Macro(shortcut: "ok", text: "good"),
    ]
    settings.save(to: defaults)
    expect(
        Settings.load(from: defaults).macros,
        [Macro(shortcut: "vn", text: "Vi\u{1ec7}t Nam"), Macro(shortcut: "ok", text: "good")],
        "macro cleanup"
    )

    // Shorthand and apps: trim, shorthand lowercased, empty and duplicate entries dropped.
    settings.shorthand = [" \u{0110}T ", "", "\u{0111}t", "ab"]
    settings.appRules = [
        AppRule(bundleID: " com.apple.Terminal ", enabled: false),
        AppRule(bundleID: ""),
        AppRule(bundleID: "com.apple.Terminal", insertion: .direct),
        AppRule(bundleID: "com.googlecode.iterm2"),
    ]
    settings.save(to: defaults)
    expect(Settings.load(from: defaults).shorthand, ["\u{0111}t", "ab"], "shorthand cleanup")
    expect(
        Settings.load(from: defaults).appRules,
        [AppRule(bundleID: "com.apple.Terminal", enabled: false), AppRule(bundleID: "com.googlecode.iterm2")],
        "appRules cleanup"
    )

    // Wrong stored types fall back to the field default.
    defaults.set("oops", forKey: "macros")
    defaults.set(5, forKey: "shorthand")
    defaults.set("x", forKey: "appRules")
    let fallback = Settings.load(from: defaults)
    expect(fallback.macros, [], "macros wrong type")
    expect(fallback.shorthand, ["\u{0111}c"], "shorthand wrong type")
    expect(fallback.appRules, [], "appRules wrong type")

    // Apps excluded before per-app rules existed stay off, and saving drops the old key.
    let legacy = UserDefaults(suiteName: suite + ".legacy")!
    defer { legacy.removePersistentDomain(forName: suite + ".legacy") }
    legacy.set(["com.apple.Terminal"], forKey: "excludedApps")
    let migrated = Settings.load(from: legacy)
    expect(migrated.appRules, [AppRule(bundleID: "com.apple.Terminal", enabled: false)], "excludedApps migrates")
    migrated.save(to: legacy)
    expect(legacy.object(forKey: "excludedApps") == nil, true, "old key removed on save")
    expect(Settings.load(from: legacy), migrated, "migrated rules persist")

    // A user who removed every shorthand word keeps an empty list.
    var emptied = Settings()
    emptied.shorthand = []
    emptied.save(to: defaults)
    expect(Settings.load(from: defaults).shorthand, [], "empty shorthand is kept")
}

func checkMacroProblems() {
    let first = Macro(shortcut: "vn", text: "Vi\u{1ec7}t Nam")
    let dup = Macro(shortcut: "VN", text: "again")
    let noText = Macro(shortcut: "ko", text: "")
    let noKey = Macro(shortcut: "", text: "x")
    let digit = Macro(shortcut: "a1", text: "x")
    let problems = Macro.problems(in: [first, dup, noText, noKey, digit])
    expect(problems[first.id], nil, "first row has no problem")
    expect(problems[dup.id], .duplicate, "case duplicate")
    expect(problems[noText.id], .emptyText, "empty text")
    expect(problems[noKey.id], .badShortcut, "empty shortcut")
    expect(problems[digit.id], .badShortcut, "digit shortcut")
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

/// Prints the cost of one `Settings.load()` with a large macro table.
func checkLoadTiming() {
    let suite = "ankey.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    var settings = Settings()
    let letters = Array("abcdefghijklmnopqrstuvwxyz")
    settings.macros = (0..<500).map { i in
        let key = String([letters[i % 26], letters[(i / 26) % 26], letters[(i / 676) % 26]])
        return Macro(shortcut: key, text: "expansion \(i)")
    }
    settings.save(to: defaults)
    let loads = 1000
    let start = Date()
    for _ in 0..<loads { _ = Settings.load(from: defaults) }
    let perLoad = Date().timeIntervalSince(start) / Double(loads) * 1000
    print("load with 500 macros: \(String(format: "%.3f", perLoad)) ms per load")
}

func checkExpansion() {
    var settings = Settings()
    settings.macros = [
        Macro(shortcut: "vn", text: "vi\u{1ec7}t nam"),
        Macro(shortcut: "uu", text: "\u{01b0}u ti\u{00ea}n"),
        Macro(shortcut: "dd", text: "\u{0111}\u{00e2}y"),
        Macro(shortcut: "as", text: "a-s"),
        Macro(shortcut: "v", text: "v\u{1ec1}"),
    ]
    func want(_ raw: String, _ text: String?) {
        expect(Engine.expansion(for: raw, settings), text, "expansion \(raw)")
    }
    want("vn", "vi\u{1ec7}t nam")                 // lowercase: as defined
    want("Vn", "Vi\u{1ec7}t nam")                 // first letter capitalized
    want("VN", "VI\u{1ec6}T NAM")                 // all caps
    want("vN", "vi\u{1ec7}t nam")                 // other mix: as defined
    want("V", "V\u{1ec1}")                        // single capital: capitalized
    want("Uu", "\u{01af}u ti\u{00ea}n")           // Vietnamese first letter
    want("UU", "\u{01af}U TI\u{00ca}N")           // Vietnamese uppercase
    want("xx", nil)                               // no match
    want("", nil)                                 // nothing typed
    want("dd", "\u{0111}\u{00e2}y")               // the macro wins over Telex d+d
    want("as", "a-s")                             // the macro wins over Telex tone s

    expect(Engine.expansion(for: "vn", Settings()), nil, "empty table")

    // Session: expansion matches the typed keys, not the display.
    var session = Session()
    for ch in "dd" { _ = session.push(ch) }
    expect(session.display(settings), "\u{0111}", "display of dd")
    expect(session.committed(settings, expand: true), "\u{0111}\u{00e2}y", "committed expand")
    expect(session.committed(settings, expand: false), "\u{0111}", "committed no expand")

    // Backspace edits the typed keys before the expansion is looked up.
    var edited = Session()
    for ch in "vnx" { _ = edited.push(ch) }
    expect(edited.pop(), true, "pop x")
    expect(edited.committed(settings, expand: true), "vi\u{1ec7}t nam", "expansion after backspace")
    expect(Session().committed(settings, expand: true), "", "empty session commits nothing")
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
        var settings = Settings(toneStyle: style)
        settings.keepEnglish = []
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

func checkKeepEnglish() {
    // The built-in list keeps these English with no setting saved.
    for word in ["test", "reset", "boot", "row", "saw", "law", "door", "asap"] {
        check(word, Settings(), word)
        check(word.capitalized, Settings(), word.capitalized)
        check(word.uppercased(), Settings(), word.uppercased())
    }
    check("tes", Settings(), "t\u{00e9}")
    var custom = Settings()
    custom.keepEnglish = ["tes"]
    check("tes", custom, "tes")
    check("test", custom, "test")
    // Keeping English is part of restoring raw text.
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

    let suite = "ankey.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    expect(Settings.load(from: defaults).keepEnglish, [], "keepEnglish default")
    var settings = Settings()
    settings.keepEnglish = [" TEST ", "", "test", "best"]
    settings.save(to: defaults)
    expect(Settings.load(from: defaults).keepEnglish, ["test", "best"], "keepEnglish cleanup")
    defaults.set(5, forKey: "keepEnglish")
    expect(Settings.load(from: defaults).keepEnglish, Settings().keepEnglish, "keepEnglish wrong type")
    settings.keepEnglish = []
    settings.save(to: defaults)
    expect(Settings.load(from: defaults).keepEnglish, [], "empty keepEnglish is kept")
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
        return session.finish(s, expand: false)
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
    _ = session.finish(s, expand: false)
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
    _ = forgotten.finish(s, expand: false)
    forgotten.forgetContext()
    var fresh = Session()
    expect(afterDot(&forgotten), afterDot(&fresh), "forgetContext matches a fresh session")
    // A macro says nothing about the language.
    var macro = s
    macro.macros = [Macro(shortcut: "vn", text: "vi\u{1ec7}t nam")]
    _ = typed(&session, "commit")
    for ch in "vn" { _ = session.push(ch) }
    expect(session.finish(macro, expand: true), "vi\u{1ec7}t nam", "macro expands")
    expect(typed(&session, "as"), "as", "macro keeps the earlier language")
}

/// Types a line the way the controller does: each key joins the word, or ends it.
func typeLine(_ line: String, _ settings: Settings = Settings()) -> String {
    var session = Session()
    var document = ""
    for ch in line {
        switch session.push(ch) {
        case .consumed: break
        case .pass: document.append(ch)
        case .commit:
            document += session.finish(settings, expand: true)
            document.append(ch)
        }
    }
    return document + session.finish(settings, expand: false)
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
    _ = session.finish(none, expand: false)
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


@main
struct TestRunner {
    static func main() {
        for (raw, want) in telex { check(raw, want) }
        checkSettings()
        checkMacroStorage()
        checkMacroProblems()
        checkAppRules()
        checkEncoding()
        checkRelease()
        checkLoadTiming()
        checkExpansion()
        checkShorthand()
        checkAttested()
        checkKeepEnglish()
        checkContext()
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
