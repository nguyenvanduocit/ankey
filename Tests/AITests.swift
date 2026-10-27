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
