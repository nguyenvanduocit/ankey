import Foundation

/// A scratch defaults domain, removed when `body` returns.
private func withScratchDefaults(_ body: (UserDefaults) -> Void) {
    let suite = "ankey.tests.ai.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    body(defaults)
}

func checkSettingsSave() {
    expect(Settings().keepsDiary, false, "the diary starts off")

    withScratchDefaults { defaults in
        var on = Settings()
        on.keepsDiary = true
        on.save(to: defaults)
        expect(Settings.load(from: defaults).keepsDiary, true, "keepsDiary survives save and load")
        expect(Settings.keepsDiary(in: defaults), true, "keepsDiary(in:) reads the stored switch")
    }

    // A window opened earlier holds a stale copy. Another writer changes one key, the window then saves a
    // different one: the other writer's key must stay.
    withScratchDefaults { defaults in
        Settings().save(to: defaults)
        let stale = Settings.load(from: defaults)
        defaults.set(ToneStyle.classic.rawValue, forKey: "toneStyle")
        var next = stale
        next.escClears = false
        next.save(to: defaults, replacing: stale)
        let after = Settings.load(from: defaults)
        expect(after.toneStyle, .classic, "a window save leaves a key it did not change alone")
        expect(after.escClears, false, "a window save writes the key it changed")
    }

    // Loading reads sharing as off while collection is off. A window that then switches collection on must not
    // bring back a `true` that was stored for sharing.
    withScratchDefaults { defaults in
        defaults.set(false, forKey: "collectStats")
        defaults.set(true, forKey: "shareStats")
        let stale = Settings.load(from: defaults)
        expect(stale.shareStats, false, "sharing reads as off while collection is off")
        var next = stale
        next.collectStats = true
        next.save(to: defaults, replacing: stale)
        expect(Settings.load(from: defaults).shareStats, false, "switching collection on does not resume sharing")
    }

    withScratchDefaults { defaults in
        Settings().save(to: defaults, replacing: Settings())
        expect(defaults.object(forKey: "toneStyle") == nil, true, "nothing changed, nothing written")
    }

    withScratchDefaults { defaults in
        Settings().save(to: defaults)
        let keys = [
            "toneStyle", "restoreRaw", "abbreviation", "escClears", "suggestions", "learnsPhrases",
            "learnsLanguage", "keepsDiary", "collectStats", "shareStats", "onboardingSeen", "shorthand", "appRules",
        ]
        for key in keys {
            expect(defaults.object(forKey: key) != nil, true, "save without a previous value writes \(key)")
        }
    }
}

// MARK: Config edits

private func edit(_ kind: ConfigEdit.Kind, _ key: String, _ value: String? = nil) -> ConfigEdit {
    ConfigEdit(kind: kind, key: key, value: value)
}

private func expectError(_ want: AIError, _ label: String, _ body: () throws -> Void) {
    do {
        try body()
        failed += 1
        fputs("FAIL \(label): no error, want \(want)\n", stderr)
    } catch let error as AIError {
        expect(error, want, label)
    } catch {
        failed += 1
        fputs("FAIL \(label): \(error), want \(want)\n", stderr)
    }
}

func checkAIConfig() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    // A setting changes, and the change carries the edit that puts it back.
    do {
        let result = try edit(.set, "toneStyle", "classic").applying(to: Settings(), now: now)
        expect(result.settings.toneStyle, .classic, "set toneStyle classic")
        expect(result.change?.undo, edit(.set, "toneStyle", "modern"), "the undo of a set is the old value")
        expect(result.change?.time, now, "the change carries the time it was made")
        expect(result.change?.summary.contains("classic") ?? false, true, "the summary names the new value")
        let back = try result.change!.undo!.applying(to: result.settings, now: now)
        expect(back.settings, Settings(), "applying the undo restores the setting")
    } catch { failed += 1; fputs("FAIL set toneStyle: \(error)\n", stderr) }

    do {
        let same = try edit(.set, "toneStyle", "modern").applying(to: Settings(), now: now)
        expect(same.change == nil, true, "the same value is no change")
        expect(same.settings, Settings(), "the same value leaves the settings alone")
        let flag = try edit(.set, "escClears", "off").applying(to: Settings(), now: now)
        expect(flag.settings.escClears, false, "set escClears off")
        expect(flag.change?.undo, edit(.set, "escClears", "on"), "the undo of a switch is its old state")
    } catch { failed += 1; fputs("FAIL set value: \(error)\n", stderr) }

    expectError(.badValue(key: "toneStyle", allowed: ["modern", "classic"]), "a tone style that does not exist") {
        _ = try edit(.set, "toneStyle", "purple").applying(to: Settings(), now: now)
    }
    expectError(.badValue(key: "escClears", allowed: ["on", "off"]), "a switch takes on or off") {
        _ = try edit(.set, "escClears", "maybe").applying(to: Settings(), now: now)
    }
    expectError(.unknownKey("volume"), "a setting that does not exist") {
        _ = try edit(.set, "volume", "on").applying(to: Settings(), now: now)
    }
    expectError(.emptyValue, "a blank value") {
        _ = try edit(.set, "escClears", "  ").applying(to: Settings(), now: now)
    }
    expectError(.emptyValue, "a missing value") {
        _ = try edit(.set, "escClears").applying(to: Settings(), now: now)
    }

    // What keeps or sends typed words may be switched off by an AI and never on.
    for key in SettingKey.allCases where key.humanOnly {
        expectError(.humanOnly(key.rawValue), "\(key.rawValue) on is for the user") {
            _ = try edit(.set, key.rawValue, "on").applying(to: Settings(), now: now)
        }
    }
    expect(SettingKey.allCases.filter(\.humanOnly).map(\.rawValue).sorted(),
           ["collectStats", "keepsDiary", "learnsLanguage", "learnsPhrases", "shareStats"], "the privacy switches")
    do {
        let on = Settings(learnsPhrases: true, keepsDiary: true)
        var off = try edit(.set, "learnsPhrases", "off").applying(to: on, now: now)
        expect(off.settings.learnsPhrases, false, "a privacy switch may be turned off")
        expect(off.change?.undo == nil, true, "turning a privacy switch off has no undo that turns it on")
        off = try edit(.set, "keepsDiary", "off").applying(to: off.settings, now: now)
        expect(off.settings.keepsDiary, false, "the diary may be turned off")
    } catch { failed += 1; fputs("FAIL privacy off: \(error)\n", stderr) }

    // The shorthand list.
    do {
        let added = try edit(.shorthandAdd, "KG ").applying(to: Settings(), now: now)
        expect(added.settings.shorthand, ["\u{0111}c", "kg"], "a shorthand word is trimmed and lowercased")
        expect(added.change?.undo, edit(.shorthandRemove, "kg"), "the undo of an add is a remove")
        let twice = try edit(.shorthandAdd, "kg").applying(to: added.settings, now: now)
        expect(twice.change == nil, true, "a word already listed is no change")
        let removed = try edit(.shorthandRemove, "kg").applying(to: added.settings, now: now)
        expect(removed.settings.shorthand, ["\u{0111}c"], "remove takes the word out")
        expect(removed.change?.undo, edit(.shorthandAdd, "kg"), "the undo of a remove is an add")
        let absent = try edit(.shorthandRemove, "zz").applying(to: Settings(), now: now)
        expect(absent.change == nil, true, "a word that is not listed is no change")
    } catch { failed += 1; fputs("FAIL shorthand: \(error)\n", stderr) }
    expectError(.emptyValue, "an empty shorthand word") {
        _ = try edit(.shorthandAdd, "  ").applying(to: Settings(), now: now)
    }
    expectError(.failed("A shorthand word is one word without spaces."), "a shorthand word with a space") {
        _ = try edit(.shorthandAdd, "k g").applying(to: Settings(), now: now)
    }

    // Per-app rules.
    do {
        let added = try edit(.appRule, "com.x", "off").applying(to: Settings(), now: now)
        expect(added.settings.appRules, [AppRule(bundleID: "com.x", enabled: false)], "a rule is added for an app")
        expect(added.change?.undo, edit(.appRuleRemove, "com.x"), "the undo of a new rule removes it")

        let direct = Settings(appRules: [AppRule(bundleID: "com.x", insertion: .direct)])
        let off = try edit(.appRule, "com.x", "off").applying(to: direct, now: now)
        expect(off.settings.rule(for: "com.x").mode, .off, "an existing rule changes mode")
        expect(off.change?.undo, edit(.appRule, "com.x", "direct"), "the undo of a mode change is the old mode")

        let noop = try edit(.appRule, "com.y", "marked").applying(to: Settings(), now: now)
        expect(noop.change == nil, true, "the default mode for an app without a rule is no change")

        let removed = try edit(.appRuleRemove, "com.x").applying(to: direct, now: now)
        expect(removed.settings.appRules, [], "remove takes the rule out")
        expect(removed.change?.undo, edit(.appRule, "com.x", "direct"), "the undo of a remove restores the mode")
        let none = try edit(.appRuleRemove, "com.z").applying(to: Settings(), now: now)
        expect(none.change == nil, true, "removing a rule that is not there is no change")
    } catch { failed += 1; fputs("FAIL app rules: \(error)\n", stderr) }
    expectError(.badValue(key: "mode", allowed: ["off", "marked", "direct"]), "an app mode that does not exist") {
        _ = try edit(.appRule, "com.x", "sideways").applying(to: Settings(), now: now)
    }
    expectError(.emptyValue, "an app rule without a bundle ID") {
        _ = try edit(.appRule, "  ", "off").applying(to: Settings(), now: now)
    }
}

func checkChangeLog() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func change(_ name: String, undo: ConfigEdit? = ConfigEdit(kind: .set, key: "escClears", value: "on")) -> Change {
        Change(time: now, summary: name, undo: undo)
    }

    var log = ChangeLog()
    expect(log.popUndo() == nil, true, "an empty log has nothing to undo")

    for index in 0..<(ChangeLog.capacity + 10) { log.record(change("c\(index)")) }
    expect(log.changes.count, ChangeLog.capacity, "the log keeps its capacity")
    expect(log.changes.first?.summary, "c10", "the oldest changes drop first")
    expect(log.changes.last?.summary, "c59", "the newest change stays")

    var small = ChangeLog()
    small.record(change("first"))
    small.record(change("learned", undo: nil))
    small.record(change("second"))
    expect(small.popUndo()?.1.summary, "second", "undo takes the newest change that can be undone")
    expect(small.popUndo()?.1.summary, "first", "undo skips a change that cannot be undone")
    expect(small.popUndo() == nil, true, "undo twice past the end is nothing")
    expect(small.changes.map(\.summary), ["learned"], "a change that cannot be undone stays listed")

    var saved = ChangeLog()
    saved.record(change("kept"))
    let data = try? JSONEncoder().encode(saved)
    let loaded = data.flatMap { try? JSONDecoder().decode(ChangeLog.self, from: $0) }
    expect(loaded, saved, "the log survives encode and decode")
}

// MARK: Diary

private func day(_ number: Int) -> String {
    String(format: "2026-%02d-%02d", 1 + (number - 1) / 28, 1 + (number - 1) % 28)
}

func checkDiary() {
    var diary = Diary()
    diary.record(.escRestoredRaw, raw: "vieetj", shown: "vi\u{1ec7}t", app: "com.apple.Terminal", on: "2026-10-27")
    diary.record(.flipToEnglish, raw: "as", shown: "\u{00e1}", app: "", on: "2026-10-27")
    expect(diary.entries.count, 2, "two events are two entries")
    expect(diary.entries[0], DiaryEntry(day: "2026-10-27", app: "com.apple.Terminal", kind: .escRestoredRaw, raw: "vieetj", shown: "vi\u{1ec7}t"), "an entry keeps what happened")
    expect(diary.entries[1].app, "unknown", "an app with no bundle ID is unknown")
    diary.record(.correctionToEnglish, raw: String(repeating: "x", count: 100), shown: "y", app: "a", on: "2026-10-27")
    expect(diary.entries[2].raw.count, Diary.maxWordLength, "a long word is cut")

    // The entry count is bounded and the oldest go first.
    var long = Diary()
    for index in 0..<(Diary.maxEntries + 10) { long.record(.escRestoredRaw, raw: "w\(index)", shown: "s", app: "a", on: "2026-10-27") }
    expect(long.entries.count, Diary.maxEntries, "the diary keeps its capacity")
    expect(long.entries.first?.raw, "w10", "the oldest entries drop first")
    expect(long.entries.last?.raw, "w\(Diary.maxEntries + 9)", "the newest entry stays")

    // Only the last 30 days with anything in them are kept, in entries and in word counts alike.
    var days = Diary()
    for number in 1...(Diary.keepDays + 5) {
        days.record(.flipToVietnamese, raw: "r", shown: "s", app: "a", on: day(number))
        days.countWord(app: "a", on: day(number))
    }
    expect(Set(days.entries.map(\.day)).count, Diary.keepDays, "entries keep 30 days")
    expect(days.words.count, Diary.keepDays, "word counts keep 30 days")
    expect(days.entries.first?.day, day(6), "the oldest days drop first")
    expect(days.words[day(1)] == nil, true, "a dropped day has no word counts")

    // Words committed, per app per day: the denominator for how often an app misfires.
    var counts = Diary()
    counts.countWord(app: "com.a", on: "2026-10-27")
    counts.countWord(app: "com.a", on: "2026-10-27")
    counts.countWord(app: "com.b", on: "2026-10-27")
    counts.countWord(app: "", on: "2026-10-28")
    expect(counts.words["2026-10-27"], ["com.a": 2, "com.b": 1], "words are counted per app")
    expect(counts.words["2026-10-28"], ["unknown": 1], "an unknown app is counted as unknown")

    let data = try? JSONEncoder().encode(diary)
    expect(data.flatMap { try? JSONDecoder().decode(Diary.self, from: $0) }, diary, "the diary survives encode and decode")

    diary.forgetAll()
    expect(diary, Diary(), "forgetting empties the diary")

    // Nothing the diary holds reaches the statistics that go to Datadog.
    var secret = Diary()
    secret.record(.escRestoredRaw, raw: "secretkeys", shown: "secretshown", app: "com.secret.app", on: "2026-10-27")
    secret.countWord(app: "com.secret.app", on: "2026-10-27")
    var log = StatsLog()
    log.record(.wordChanged, on: "2026-10-27")
    let payload = StatsPayload(appVersion: "1", macOS: "26", settings: Settings(keepsDiary: true), log: log)
    let body = String(data: LogIntake.body(payload.events(installID: "id")), encoding: .utf8) ?? ""
    for text in ["secretkeys", "secretshown", "com.secret.app"] {
        expect(body.contains(text), false, "the statistics payload does not carry \(text)")
    }
    expect(body.contains("keepsDiary"), false, "the statistics payload does not carry the diary switch")
}

// MARK: Command line and gateway

private func canonical(_ object: Any) -> String {
    (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])).flatMap { String(data: $0, encoding: .utf8) } ?? "<not json>"
}

func checkAICommand() {
    func setting(_ kind: ConfigEdit.Kind, _ key: String, _ value: String? = nil, dryRun: Bool = false) -> AICommand {
        .edit(ConfigEdit(kind: kind, key: key, value: value), dryRun: dryRun)
    }
    let cases: [([String], AICommand)] = [
        (["guide"], .guide),
        (["skill"], .skill),
        (["help"], .help),
        (["--help"], .help),
        (["-h"], .help),
        (["show"], .show(.all, limit: 200)),
        (["show", "learned"], .show(.learned, limit: 200)),
        (["show", "settings"], .show(.settings, limit: 200)),
        (["show", "stats"], .show(.stats, limit: 200)),
        (["show", "changes"], .show(.changes, limit: 200)),
        (["show", "diary", "--limit", "5"], .show(.diary, limit: 5)),
        (["show", "--limit", "5", "diary"], .show(.diary, limit: 5)),
        (["show", "--limit", "99999"], .show(.all, limit: 2000)),
        (["show", "--limit", "0"], .show(.all, limit: 1)),
        (["set", "toneStyle", "classic"], setting(.set, "toneStyle", "classic")),
        (["set", "escClears", "off", "--dry-run"], setting(.set, "escClears", "off", dryRun: true)),
        (["shorthand", "add", "kg"], setting(.shorthandAdd, "kg")),
        (["shorthand", "remove", "kg", "--dry-run"], setting(.shorthandRemove, "kg", dryRun: true)),
        (["app", "set", "com.x", "direct"], setting(.appRule, "com.x", "direct")),
        (["app", "remove", "com.x"], setting(.appRuleRemove, "com.x")),
        (["learned", "adjust", "COS", "-2"], .gateway(.adjust(word: "cos", score: -2))),
        (["learned", "adjust", "cos", "0"], .gateway(.adjust(word: "cos", score: 0))),
        (["learned", "forget-phrase", "xin ch\u{00e0}o", "b\u{1ea1}n"], .gateway(.forgetPhrase(prefix: "xin ch\u{00e0}o", word: "b\u{1ea1}n"))),
        (["learned", "forget-habit", "d\u{00f9}ng"], .gateway(.forgetHabit(word: "d\u{00f9}ng"))),
        (["diary", "clear"], .gateway(.diaryClear)),
        (["undo"], .undo),
    ]
    for (args, want) in cases {
        expect(AICommand.parse(args), .success(want), "parse \(args)")
    }

    let wrong: [[String]] = [
        [], ["frobnicate"], ["set"], ["set", "toneStyle"], ["set", "a", "b", "c"], ["set", "a", "b", "--frob"],
        ["show", "bogus"], ["show", "--limit"], ["show", "--limit", "x"], ["show", "learned", "diary"],
        ["shorthand"], ["shorthand", "add"], ["shorthand", "toggle", "kg"],
        ["app"], ["app", "set", "com.x"], ["app", "remove"], ["app", "frob", "com.x"],
        ["learned"], ["learned", "adjust", "cos"], ["learned", "adjust", "cos", "3"], ["learned", "adjust", "cos", "two"],
        ["learned", "forget-phrase", "only"], ["learned", "forget-habit"],
        ["diary"], ["diary", "wipe"], ["undo", "now"], ["guide", "--dry-run"], ["learned", "adjust", "cos", "1", "--dry-run"],
    ]
    for args in wrong {
        switch AICommand.parse(args) {
        case .failure(.usage): break
        default:
            failed += 1
            fputs("FAIL parse \(args) is a usage error\n", stderr)
        }
    }
    expect(AICommand.parse(["set"]) == .failure(.usage("Usage: Ankey set <key> <value> [--dry-run]")), true, "a usage error says how to call it")

    for verb in ["guide", "skill", "help", "show", "set", "shorthand", "app", "learned", "diary", "undo"] {
        expect(AICommand.isVerb(verb), true, "\(verb) is a verb")
    }
    for other in ["enable", "-psn_0_12345", "", "--help-me"] { expect(AICommand.isVerb(other), false, "\(other) starts the input method") }
    expect(AICommand.isVerb(nil), false, "no argument starts the input method")
}

func checkGateway() {
    let id = "5B9B2C0E-3E5B-4C58-9B1D-6D9E2B0F1A11"
    let requests: [GatewayRequest] = [
        .adjust(word: "cos", score: -2), .adjust(word: "x", score: 0), .forgetPhrase(prefix: "xin ch\u{00e0}o", word: "b\u{1ea1}n"),
        .forgetHabit(word: "d\u{00f9}ng"), .diaryClear, .snapshot(limit: 50),
    ]
    for request in requests {
        let message = GatewayMessage(id: id, request: request)
        expect(GatewayMessage(userInfo: message.userInfo), message, "a message survives its userInfo: \(request)")
    }
    expect(GatewayMessage(userInfo: ["id": id]) == nil, true, "a message needs a name")
    expect(GatewayMessage(userInfo: ["name": "diaryClear"]) == nil, true, "a message needs an id")
    // The ID names the snapshot file the app writes, and any process can post a request, so it must be a UUID.
    for bad in ["abc", "../x", "x/../../y", ""] {
        expect(GatewayMessage(userInfo: ["id": bad, "name": "diaryClear"]) == nil, true, "an ID that is not a UUID is not a message: \(bad)")
    }
    expect(GatewayMessage(userInfo: ["id": id, "name": "explode"]) == nil, true, "an unknown name is not a message")
    expect(GatewayMessage(userInfo: ["id": id, "name": "adjust", "word": "cos"]) == nil, true, "adjust needs a score")
    expect(GatewayMessage(userInfo: ["id": id, "name": "adjust", "word": "cos", "score": "9"]) == nil, true, "a score out of range is not a message")
    expect(GatewayMessage(userInfo: ["id": id, "name": "snapshot", "limit": "0"]) == nil, true, "a limit below 1 is not a message")
    expect(GatewayMessage(userInfo: ["id": id, "name": "forgetPhrase", "prefix": "a"]) == nil, true, "forgetPhrase needs a word")

    // A reply says whether it worked. It never carries typed words: every process of the login session can read it.
    for reply in [GatewayReply(id: id, ok: true, message: "done"), GatewayReply(id: id, ok: false, message: "no")] {
        expect(GatewayReply(userInfo: reply.userInfo), reply, "a reply survives its userInfo")
    }
    expect(Set(GatewayReply(id: id, ok: true, message: "done").userInfo.keys), ["id", "ok", "message"], "a reply holds an ID, a verdict and a sentence")
    expect(GatewayReply(userInfo: ["id": id, "message": "m"]) == nil, true, "a reply needs ok")
    expect(GatewayReply(userInfo: ["id": id, "ok": "maybe", "message": "m"]) == nil, true, "ok is true or false")
    expect(Gateway.requestName != Gateway.replyName, true, "requests and replies travel on different names")
}

func checkAIReport() {
    let settings = AIReport.settings(Settings(toneStyle: .classic, shorthand: ["kg"], appRules: [AppRule(bundleID: "com.x", enabled: false)]))
    expect(Set(settings.keys), [
        "toneStyle", "restoreRaw", "abbreviation", "escClears", "suggestions", "learnsPhrases", "learnsLanguage", "keepsDiary",
        "collectStats", "shareStats", "onboardingSeen", "shorthand", "appRules",
    ], "the settings report lists every saved setting and nothing learned")
    expect(settings["toneStyle"] as? String, "classic", "the tone style is a name")
    expect(settings["keepsDiary"] as? Bool, false, "a switch is a bool")
    expect(settings["shorthand"] as? [String], ["kg"], "the shorthand list")
    expect(canonical(settings["appRules"] as Any), #"[{"bundleID":"com.x","mode":"off"}]"#, "an app rule is its mode")

    let learned = AIReport.learned(
        adjust: ["cos": -2, "chair": 2],
        phrases: [(prefix: "xin ch\u{00e0}o", word: "b\u{1ea1}n", count: 7)],
        habits: [(word: "d\u{00f9}ng", language: .english, samples: 12)],
        source: "live")
    expect(canonical(learned),
           #"{"habits":[{"language":"english","samples":12,"word":"d\#u{00f9}ng"}],"phrases":[{"count":7,"prefix":"xin ch\#u{00e0}o","word":"b\#u{1ea1}n"}],"source":"live","words":[{"score":2,"word":"chair"},{"score":-2,"word":"cos"}]}"#,
           "the learned report")

    var log = StatsLog()
    log.record(.wordKept, on: "2026-10-27")
    log.record(.wordChanged, on: "2026-10-26")
    log.record(.wordChanged, on: "2026-10-26")
    let stats = AIReport.stats(log)
    let days = stats["days"] as? [[String: Any]]
    expect(days?.map { $0["day"] as? String ?? "" }, ["2026-10-26", "2026-10-27"], "stats days run oldest first")
    let counts = days?.first?["counts"] as? [String: Int]
    expect(counts?["wordChanged"], 2, "a day carries its counts")
    expect(counts?["wordKept"], 0, "an event that did not happen is zero")
    expect(counts?.count, StatsEvent.allCases.count, "every event is listed")
    expect(stats["keepDays"] as? Int, StatsLog.keepDays, "the report says how long the Mac keeps days")
    expect(canonical(stats).lowercased().contains("install"), false, "the install id is not in the report")

    expect(canonical(AIReport.diary(nil, limit: 10)), #"{"enabled":false}"#, "no diary reads as off")
    var diary = Diary()
    diary.record(.escRestoredRaw, raw: "a1", shown: "x", app: "com.t", on: "2026-10-26")
    diary.record(.escRestoredRaw, raw: "a2", shown: "y", app: "com.t", on: "2026-10-27")
    diary.record(.flipToEnglish, raw: "a3", shown: "z", app: "com.m", on: "2026-10-27")
    for _ in 0..<10 { diary.countWord(app: "com.t", on: "2026-10-26") }
    for _ in 0..<5 { diary.countWord(app: "com.m", on: "2026-10-27") }
    diary.countWord(app: "com.q", on: "2026-10-27")
    let report = AIReport.diary(diary, limit: 2)
    expect(report["enabled"] as? Bool, true, "a diary reads as on")
    expect(report["entryCount"] as? Int, 3, "the report counts every entry")
    let entries = report["entries"] as? [[String: Any]]
    expect(entries?.map { $0["raw"] as? String ?? "" }, ["a3", "a2"], "entries run newest first, up to the limit")
    expect(canonical(report["apps"] as Any),
           #"[{"app":"com.t","byKind":{"escRestoredRaw":2},"events":2,"words":10},{"app":"com.m","byKind":{"flipToEnglish":1},"events":1,"words":5},{"app":"com.q","byKind":{},"events":0,"words":1}]"#,
           "each app with its words, events and the kinds of event")

    var changes = ChangeLog()
    changes.record(Change(time: Date(timeIntervalSince1970: 0), summary: "first", undo: ConfigEdit(kind: .set, key: "escClears", value: "on")))
    changes.record(Change(time: Date(timeIntervalSince1970: 60), summary: "second", undo: nil))
    expect(canonical(AIReport.changes(changes)),
           #"{"changes":[{"summary":"second","time":"1970-01-01T00:01:00Z","undoable":false},{"summary":"first","time":"1970-01-01T00:00:00Z","undoable":true}]}"#,
           "changes run newest first")
}

// MARK: Follow-ups, snapshot and the guide

func checkAIFollowUps() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    // The Statistics tab turns sharing off together with collection, so the command line does too.
    do {
        let both = Settings(collectStats: true, shareStats: true)
        let result = try ConfigEdit(kind: .set, key: "collectStats", value: "off").applying(to: both, now: now)
        expect(result.settings.collectStats, false, "collection goes off")
        expect(result.settings.shareStats, false, "sharing goes off with collection")
        let sharing = try ConfigEdit(kind: .set, key: "shareStats", value: "off").applying(to: both, now: now)
        expect(sharing.settings.collectStats, true, "sharing off leaves collection on")
    } catch { failed += 1; fputs("FAIL follow-ups: \(error)\n", stderr) }

    let snapshot = AIReport.snapshot(adjust: [:], phrases: [], habits: [], diary: nil, limit: 5, source: "files")
    expect(Set(snapshot.keys), ["learned", "diary"], "a snapshot holds what only the running app keeps")
    expect((snapshot["learned"] as? [String: Any])?["source"] as? String, "files", "a snapshot says where it came from")
    expect(canonical(snapshot["diary"] as Any), #"{"enabled":false}"#, "a snapshot with no diary reads as off")
}

/// The guide is what an AI reads to use the command line, so it must name every command, setting and counter.
func checkAIGuide() {
    guard let data = FileManager.default.contents(atPath: "Resources/ai-guide.md"), let guide = String(data: data, encoding: .utf8) else {
        failed += 1
        fputs("FAIL Resources/ai-guide.md is not readable from \(FileManager.default.currentDirectoryPath)\n", stderr)
        return
    }
    let commands = [
        "show", "set", "shorthand add", "shorthand remove", "app set", "app remove", "learned adjust",
        "learned forget-phrase", "learned forget-habit", "diary clear", "undo",
    ]
    for command in commands { expect(guide.contains("ankey \(command)"), true, "the guide explains `ankey \(command)`") }
    for key in SettingKey.allCases { expect(guide.contains(key.rawValue), true, "the guide names the setting \(key.rawValue)") }
    for event in StatsEvent.allCases { expect(guide.contains(event.rawValue), true, "the guide explains the counter \(event.rawValue)") }
    for kind in DiaryKind.allCases { expect(guide.contains(kind.rawValue), true, "the guide explains the diary kind \(kind.rawValue)") }
}

// MARK: Diary store

private func waitUntil(_ condition: () -> Bool) -> Bool {
    for _ in 0..<100 {
        if condition() { return true }
        Thread.sleep(forTimeInterval: 0.02)
    }
    return condition()
}

func checkDiaryStore() {
    let suite = "ankey.tests.diarystore.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ankey-diary-\(UUID().uuidString)")
    defer {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: dir)
    }
    let file = dir.appendingPathComponent("diary.json")
    func exists() -> Bool { FileManager.default.fileExists(atPath: file.path) }

    // Off: nothing is kept, nothing is written.
    let store = DiaryStore(file: file, defaults: defaults)
    store.record(.escRestoredRaw, raw: "vieetj", shown: "vi\u{1ec7}t", app: "com.t")
    store.countWord(app: "com.t")
    store.flush()
    Thread.sleep(forTimeInterval: 0.2)
    expect(store.snapshot() == nil, true, "an off diary reads as off")
    expect(exists(), false, "an off diary writes no file")

    // On: events are kept, written with a mode only the user can read, and survive a restart.
    defaults.set(true, forKey: "keepsDiary")
    store.record(.escRestoredRaw, raw: "vieetj", shown: "vi\u{1ec7}t", app: "com.t")
    store.countWord(app: "com.t")
    expect(store.snapshot()?.entries.count, 1, "an on diary keeps an event")
    expect(store.snapshot()?.words.values.flatMap(\.values).reduce(0, +), 1, "an on diary counts a word")
    store.flush()
    expect(waitUntil(exists), true, "flushing writes the file")
    let mode = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.posixPermissions] as? Int
    expect(waitUntil { ((try? FileManager.default.attributesOfItem(atPath: file.path))?[.posixPermissions] as? Int) == 0o600 }, true, "the file is readable by the user only (mode \(String(describing: mode)))")
    let restarted = DiaryStore(file: file, defaults: defaults)
    expect(restarted.snapshot()?.entries.first?.raw, "vieetj", "a new store reads what was written")

    // Switching off deletes what was kept, in the file and in memory.
    defaults.set(false, forKey: "keepsDiary")
    store.flush()
    expect(waitUntil { !exists() }, true, "an off switch deletes the file at the next flush")
    expect(store.snapshot() == nil, true, "an off diary reads as off after the switch")
    defaults.set(true, forKey: "keepsDiary")
    expect(store.snapshot()?.entries.count, 0, "a diary switched on again starts empty")

    // Forgetting removes the file even while the diary is on.
    store.record(.flipToEnglish, raw: "as", shown: "\u{00e1}", app: "com.t")
    store.flush()
    expect(waitUntil(exists), true, "the diary is written again")
    store.forgetAll()
    expect(waitUntil { !exists() }, true, "forgetting deletes the file")
    expect(store.snapshot()?.entries.count, 0, "forgetting empties the diary")

    // A file left from when the diary was on does not survive a launch with the switch off.
    store.record(.flipToEnglish, raw: "as", shown: "\u{00e1}", app: "com.t")
    store.flush()
    expect(waitUntil(exists), true, "a leftover file exists")
    defaults.set(false, forKey: "keepsDiary")
    _ = DiaryStore(file: file, defaults: defaults)
    expect(waitUntil { !exists() }, true, "a launch with the switch off deletes the leftover file")

    // A file that cannot be read is still words the user was told would go with the switch.
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try? Data("not json".utf8).write(to: file)
    expect(exists(), true, "an unreadable diary file exists")
    defaults.set(false, forKey: "keepsDiary")
    _ = DiaryStore(file: file, defaults: defaults)
    expect(waitUntil { !exists() }, true, "a diary file that cannot be read is deleted with the switch")
}

// MARK: Files

func checkAIFiles() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ankey-aifiles-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let id = "5B9B2C0E-3E5B-4C58-9B1D-6D9E2B0F1A11"

    // A snapshot of what the app holds goes to the command line as a file only the user can read.
    do {
        try AIFiles.writeSnapshot("{\"learned\":{}}", id: id, in: dir)
        let mode = (try? FileManager.default.attributesOfItem(atPath: AIFiles.snapshotFile(id: id, in: dir).path))?[.posixPermissions] as? Int
        expect(mode, 0o600, "a snapshot is readable by the user only")
        expect(AIFiles.takeSnapshot(id: id, in: dir).flatMap { String(data: $0, encoding: .utf8) }, "{\"learned\":{}}", "taking a snapshot returns it")
        expect(FileManager.default.fileExists(atPath: AIFiles.snapshotFile(id: id, in: dir).path), false, "taking a snapshot deletes it")
        expect(AIFiles.takeSnapshot(id: id, in: dir) == nil, true, "a snapshot that is not there is nil")
    } catch { failed += 1; fputs("FAIL snapshot: \(error)\n", stderr) }

    // One the command line never took (it was killed) is typed words left behind: old ones are deleted.
    do {
        let old = "AAAAAAAA-3E5B-4C58-9B1D-6D9E2B0F1A11"
        try AIFiles.writeSnapshot("{}", id: old, in: dir)
        try AIFiles.writeSnapshot("{}", id: id, in: dir)
        let past = Date(timeIntervalSinceNow: -600)
        try FileManager.default.setAttributes([.modificationDate: past], ofItemAtPath: AIFiles.snapshotFile(id: old, in: dir).path)
        AIFiles.sweepSnapshots(olderThan: 60, in: dir)
        expect(FileManager.default.fileExists(atPath: AIFiles.snapshotFile(id: old, in: dir).path), false, "an old snapshot is swept")
        expect(FileManager.default.fileExists(atPath: AIFiles.snapshotFile(id: id, in: dir).path), true, "a new snapshot is kept")
    } catch { failed += 1; fputs("FAIL sweep: \(error)\n", stderr) }

    // Two command lines at once (an AI may run two commands in one turn) must not lose a change.
    do {
        let count = 24
        DispatchQueue.concurrentPerform(iterations: count) { index in
            try? AIFiles.updateChangeLog(in: dir) { log in
                log.record(Change(time: Date(), summary: "change \(index)", undo: nil))
            }
        }
        let log = AIFiles.readChangeLog(in: dir)
        expect(log.changes.count, count, "every change made at the same time is in the log")
        expect(Set(log.changes.map(\.summary)).count, count, "no change is in the log twice")
    }

    // A change that fails to apply leaves the log as it was.
    do {
        struct Refused: Error {}
        let before = AIFiles.readChangeLog(in: dir)
        _ = try? AIFiles.updateChangeLog(in: dir) { (log: inout ChangeLog) -> Int in
            log.record(Change(time: Date(), summary: "never written", undo: nil))
            throw Refused()
        }
        expect(AIFiles.readChangeLog(in: dir), before, "a failed update leaves the log alone")
    }
}

// MARK: Where the user finds a setting

func checkSettingTabs() {
    // The learning and suggestion switches live in the AI tab, with what they learned, and a refusal tells an AI
    // which tab to send the user to.
    for key in [SettingKey.suggestions, .learnsPhrases, .learnsLanguage, .keepsDiary] {
        expect(key.tab, "AI", "\(key.rawValue) is in the AI tab")
    }
    for key in [SettingKey.toneStyle, .restoreRaw, .escClears] { expect(key.tab, "Chung", "\(key.rawValue) is in the Chung tab") }
    expect(SettingKey.abbreviation.tab, "Vi\u{1ebf}t t\u{1eaf}t", "abbreviation is in the Viết tắt tab")
    expect(SettingKey.collectStats.tab, "Th\u{1ed1}ng k\u{00ea}", "collectStats is in the Thống kê tab")
    expect(AIError.humanOnly("learnsPhrases").message.contains("tab AI"), true, "the refusal for learnsPhrases names the AI tab")
}

// MARK: The AI prompt and its cheat code

func checkAIPrompt() {
    let path = "/Users/x/Library/Input Methods/Ankey.app/Contents/MacOS/Ankey"
    let text = AIPrompt.text(executable: path)
    expect(text.contains("\"\(path)\" guide"), true, "the prompt quotes the executable, which has spaces in its path, and says guide")
    // A chat box that sends on Return must not send it half typed.
    expect(text.contains("\n"), false, "the prompt is one line")
    expect(text.isEmpty, false, "the prompt has words")
}

func checkPromptTrigger() {
    expect(Trigger.prompt.code, "///ai", "the AI code")
    expect(Trigger(typed: "///ai"), .prompt, "exact AI code")
    expect(Trigger(typed: "///AI"), .prompt, "the AI code ignores case")
    for text in ["///a", "///ai", "///AI"] { expect(Trigger.canStart(text), true, "\(text) can still become a trigger") }
    for text in ["///aix", "///ai ", "///aii", "///a i", "//ai"] { expect(Trigger.canStart(text), false, "\(text) cannot become a trigger") }
    expect(Trigger(typed: "///aix"), nil, "///aix is not a trigger")

    // It acts at once, like the settings code: held while it can grow, gone when it completes.
    var session = Session()
    for ch in "///a" { _ = session.push(ch) }
    expect(session.isHolding, true, "the prefix shared with ankey is held")
    expect(session.push("i"), .cheat(.prompt), "i completes the AI code")
    expect(session.isComposing, false, "activation leaves nothing pending")
    expect(session.display(Settings()), "", "activation leaves nothing to show")

    // The other branch from the same prefix still completes.
    session = Session()
    var last = Push.pass
    for ch in "///ankey" { last = session.push(ch) }
    expect(last, .cheat(.settings), "the settings code still completes after the shared prefix")

    // A word that merely starts like the code is an ordinary word.
    session = Session()
    var pushes: [Push] = []
    for ch in "///air" { pushes.append(session.push(ch)) }
    expect(pushes.contains(.cheat(.prompt)), true, "the code fires as soon as it is complete")
}
