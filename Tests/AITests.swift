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
