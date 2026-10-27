import Cocoa

/// The command line: `Ankey show`, `Ankey set ...`. It is the Ankey executable itself, started with a command
/// instead of by macOS, so the input method needs no second binary and no install step. Settings are read and
/// written through `UserDefaults`, which the running input method re-reads on every key. Only what the key path
/// keeps in memory goes through the running app, over the gateway.
enum AICLI {
    private static let replyTimeout: TimeInterval = 2

    /// The exit status when `args` is a command, or nil when the process should start as the input method.
    static func run(_ args: [String]) -> Int32? {
        guard AICommand.isVerb(args.first) else { return nil }
        switch AICommand.parse(args) {
        case .failure(let error): return fail(error)
        case .success(let command): return execute(command)
        }
    }

    private static func execute(_ command: AICommand) -> Int32 {
        switch command {
        case .help:
            print(AICommand.usage)
            return 0
        case .guide:
            guard let url = Bundle.main.url(forResource: "ai-guide", withExtension: "md"),
                  let text = try? String(contentsOf: url, encoding: .utf8) else {
                return fail(.failed("The guide is missing from this build of Ankey."))
            }
            print(text, terminator: "")
            return 0
        case .skill:
            print(skillText())
            return 0
        case .show(let topic, let limit): return show(topic, limit: limit)
        case .edit(let change, let dryRun): return edit(change, dryRun: dryRun)
        case .undo: return undo()
        case .gateway(let request): return send(request)
        }
    }

    // MARK: Read

    private static func show(_ topic: ShowTopic, limit: Int) -> Int32 {
        let settings = Settings.load()
        var result: [String: Any] = [:]
        if topic == .all { result["app"] = appInfo() }
        if topic == .all || topic == .settings { result["settings"] = AIReport.settings(settings) }
        if topic == .all || topic == .stats {
            var stats = AIReport.stats(StatsStore.load())
            stats["collecting"] = settings.collectStats
            result["stats"] = stats
        }
        if topic == .all || topic == .changes { result.merge(AIReport.changes(AIFiles.readChangeLog())) { _, new in new } }
        if topic == .all || topic == .learned || topic == .diary {
            let memory = memorySnapshot(limit: limit)
            if topic != .diary { result["learned"] = memory["learned"] }
            if topic != .learned { result["diary"] = memory["diary"] }
        }
        return emit(result)
    }

    /// The running app's answer, or the files when it is not running or does not answer.
    private static func memorySnapshot(limit: Int) -> [String: Any] {
        if isRunning, let reply = ask(.snapshot(limit: limit)), reply.ok, let json = reply.json,
           let object = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] {
            return object
        }
        return AIReport.snapshot(
            adjust: AdjustStore.shared.words,
            phrases: PersonalPhrasesStore.shared.learned(limit: limit),
            habits: LanguageHabitsStore.shared.learned(limit: limit),
            diary: DiaryStore.stored(),
            limit: limit,
            source: "files")
    }

    private static func appInfo() -> [String: Any] {
        [
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "running": isRunning,
            "executable": executable,
        ]
    }

    // MARK: Write

    private static func edit(_ change: ConfigEdit, dryRun: Bool) -> Int32 {
        let before = Settings.load()
        do {
            let result = try change.applying(to: before)
            guard let made = result.change else {
                return emit(["ok": true, "changed": false, "message": "The settings already say that."])
            }
            if !dryRun {
                // The log first, so a change that took effect is always one the user can see and undo.
                try record(made)
                result.settings.save(replacing: before)
                followUp(from: before, to: result.settings)
            }
            return emit(["ok": true, "changed": true, "dryRun": dryRun, "change": made.summary, "undoable": made.undo != nil])
        } catch let error as AIError {
            return fail(error)
        } catch {
            return fail(.failed("\(error)"))
        }
    }

    private static func undo() -> Int32 {
        var log = AIFiles.readChangeLog()
        guard let popped = log.popUndo() else { return fail(.failed("Nothing to undo.")) }
        let before = Settings.load()
        do {
            let result = try popped.edit.applying(to: before)
            try AIFiles.writeChangeLog(log)
            result.settings.save(replacing: before)
            followUp(from: before, to: result.settings)
            return emit([
                "ok": true,
                "undone": popped.change.summary,
                "now": result.change?.summary ?? "no change: the setting already had that value",
            ])
        } catch let error as AIError {
            return fail(error)
        } catch {
            return fail(.failed("\(error)"))
        }
    }

    /// What the Settings window does besides flipping a switch off: the counters go with collection, the install
    /// ID with sharing, the diary with its switch.
    private static func followUp(from before: Settings, to after: Settings) {
        if before.collectStats, !after.collectStats { StatsStore.clear() }
        if before.shareStats, !after.shareStats { StatsStore.forgetSharing() }
        // A running app deletes the diary at once. One that is not running deletes it when it starts.
        if before.keepsDiary, !after.keepsDiary, isRunning { _ = ask(.diaryClear) }
    }

    private static func send(_ request: GatewayRequest) -> Int32 {
        guard isRunning else {
            return fail(.unreachable("Ankey is not running. Click into a text field with Ankey as the input source, then run the command again."))
        }
        guard let reply = ask(request) else {
            return fail(.unreachable("Ankey did not answer within \(Int(replyTimeout)) seconds."))
        }
        guard reply.ok else { return fail(.failed(reply.message)) }
        try? record(Change(time: Date(), summary: reply.message, undo: nil))
        return emit(["ok": true, "message": reply.message])
    }

    private static func record(_ change: Change) throws {
        var log = AIFiles.readChangeLog()
        log.record(change)
        try AIFiles.writeChangeLog(log)
    }

    // MARK: Gateway

    private static var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "").isEmpty
    }

    /// Posts the request and waits for the reply that carries its ID. Nil when nothing answers in time.
    private static func ask(_ request: GatewayRequest) -> GatewayReply? {
        let id = UUID().uuidString
        let box = ReplyBox()
        let center = DistributedNotificationCenter.default()
        let observer = center.addObserver(forName: Notification.Name(Gateway.replyName), object: nil, queue: .main) { note in
            if let info = note.userInfo as? [String: String], let reply = GatewayReply(userInfo: info), reply.id == id {
                box.reply = reply
            }
        }
        defer { center.removeObserver(observer) }
        center.postNotificationName(
            Notification.Name(Gateway.requestName), object: nil,
            userInfo: GatewayMessage(id: id, request: request).userInfo, deliverImmediately: true)
        let deadline = Date().addingTimeInterval(replyTimeout)
        while box.reply == nil, Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        return box.reply
    }

    // MARK: Output

    private static var executable: String { Bundle.main.executablePath ?? CommandLine.arguments[0] }

    private static func emit(_ object: [String: Any]) -> Int32 {
        print(AIJSON.text(object))
        return 0
    }

    private static func fail(_ error: AIError) -> Int32 {
        fputs(AIJSON.text(["ok": false, "error": error.message]) + "\n", stderr)
        return 1
    }

    /// A SKILL.md for Claude Code. It only points at the guide, which the installed app serves, so the skill cannot
    /// drift from the version that is installed.
    private static func skillText() -> String {
        """
        ---
        name: ankey
        description: Read what the Ankey input method knows about the user (settings, learned words, counters) and change its settings. Use when the user talks about Ankey, bộ gõ, gõ tiếng Việt, Telex, cấu hình bộ gõ, or wants to tune how Ankey converts words, protects English words, abbreviations (viết tắt) or per-app behavior.
        ---

        # Ankey

        Ankey is installed on this Mac. Run its guide and follow it:

        ```
        "\(executable)" guide
        ```

        The guide comes from the installed app, so it always matches the installed version.
        """
    }
}

/// The reply that arrives while the run loop spins. A class, because the observer closure runs elsewhere.
private final class ReplyBox: @unchecked Sendable {
    var reply: GatewayReply?
}
