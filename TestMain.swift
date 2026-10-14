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
    ("khoongf", "kh\u{1ed3}ng"),
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
    expect(Settings.load(from: defaults).excludedApps, [], "excludedApps default")

    // Round trip.
    var settings = Settings()
    settings.macros = [
        Macro(shortcut: "vn", text: "Vi\u{1ec7}t Nam"),
        Macro(shortcut: "ko", text: "kh\u{00f4}ng"),
    ]
    settings.shorthand = ["\u{0111}t"]
    settings.excludedApps = ["com.apple.Terminal"]
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
    settings.excludedApps = [" com.apple.Terminal ", "", "com.apple.Terminal", "com.googlecode.iterm2"]
    settings.save(to: defaults)
    expect(Settings.load(from: defaults).shorthand, ["\u{0111}t", "ab"], "shorthand cleanup")
    expect(
        Settings.load(from: defaults).excludedApps,
        ["com.apple.Terminal", "com.googlecode.iterm2"],
        "excludedApps cleanup"
    )

    // Wrong stored types fall back to the field default.
    defaults.set("oops", forKey: "macros")
    defaults.set(5, forKey: "shorthand")
    defaults.set("x", forKey: "excludedApps")
    let fallback = Settings.load(from: defaults)
    expect(fallback.macros, [], "macros wrong type")
    expect(fallback.shorthand, ["\u{0111}c"], "shorthand wrong type")
    expect(fallback.excludedApps, [], "excludedApps wrong type")

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

func checkExclusion() {
    var settings = Settings()
    settings.excludedApps = ["com.apple.Terminal"]
    expect(settings.isExcluded(bundleID: "com.apple.Terminal"), true, "excluded match")
    expect(settings.isExcluded(bundleID: "com.apple.TextEdit"), false, "not excluded")
    expect(settings.isExcluded(bundleID: nil), false, "nil bundle id")
    expect(settings.isExcluded(bundleID: ""), false, "empty bundle id")
    expect(Settings().isExcluded(bundleID: "com.apple.Terminal"), false, "empty list excludes nothing")
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

    let json = """
    {
      "tag_name": "v1.1.0",
      "body": "Fix tones",
      "assets": [
        {"name": "Ankey-1.1.0.zip", "browser_download_url": "https://github.com/nguyenvanduocit/ankey/releases/download/v1.1.0/Ankey-1.1.0.zip"},
        {"name": "Ankey-1.1.0.zip.sha256", "browser_download_url": "https://github.com/nguyenvanduocit/ankey/releases/download/v1.1.0/Ankey-1.1.0.zip.sha256"}
      ]
    }
    """
    let info = ReleaseInfo.parse(json: Data(json.utf8))
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
    let good = "https://github.com/nguyenvanduocit/ankey/releases/download/v1.1.0/Ankey-1.1.0.zip"
    let goodSum = good + ".sha256"
    expect(ReleaseInfo.parse(json: release(zip: good, checksum: goodSum))?.notes, "", "null body is empty notes")
    expect(ReleaseInfo.parse(json: release(zip: "http://github.com/nguyenvanduocit/ankey/releases/download/v1.1.0/Ankey-1.1.0.zip", checksum: goodSum)) == nil, true, "http rejected")
    expect(ReleaseInfo.parse(json: release(zip: "https://evil.example/nguyenvanduocit/ankey/releases/download/v1.1.0/Ankey-1.1.0.zip", checksum: goodSum)) == nil, true, "foreign host rejected")
    expect(ReleaseInfo.parse(json: release(zip: "https://github.com/other/repo/releases/download/v1.1.0/Ankey-1.1.0.zip", checksum: goodSum)) == nil, true, "foreign repo rejected")
    expect(ReleaseInfo.parse(json: release(tag: "latest", zip: good, checksum: goodSum)) == nil, true, "bad tag rejected")
    expect(ReleaseInfo.parse(json: Data("{\"tag_name\": \"v1.1.0\", \"assets\": []}".utf8)) == nil, true, "no assets rejected")
    expect(ReleaseInfo.parse(json: Data("not json".utf8)) == nil, true, "garbage rejected")

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

/// Optional argument: a file with one real Vietnamese syllable per line.
func checkCorpus(_ path: String) {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        fputs("cannot read \(path)\n", stderr)
        exit(2)
    }
    var total = 0
    for syllable in text.split(separator: "\n").map(String.init) {
        total += 1
        let keys = telexKeys(syllable)
        for (mode, raw) in [("inline", keys.inline), ("deferred", keys.deferred)] {
            let got = Engine.render(raw)
            if got != syllable {
                failed += 1
                fputs("FAIL corpus \(mode) \(raw) → \(got), want \(syllable)\n", stderr)
            }
        }
    }
    print("corpus \(total) syllables")
}

@main
struct TestRunner {
    static func main() {
        for (raw, want) in telex { check(raw, want) }
        checkSettings()
        checkMacroStorage()
        checkMacroProblems()
        checkExclusion()
        checkRelease()
        checkLoadTiming()
        checkExpansion()
        checkShorthand()
        if CommandLine.arguments.count > 1 { checkCorpus(CommandLine.arguments[1]) }

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
