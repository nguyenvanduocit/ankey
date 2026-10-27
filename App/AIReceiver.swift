import Foundation

/// The running app's side of the gateway. The command line posts a request over `DistributedNotificationCenter`
/// and waits for the reply with the same ID. Only what the key path keeps in memory goes through here: the
/// learned words, phrases and habits, and the diary. Settings travel through `UserDefaults` and need no request.
///
/// Any process of the user can post a request, the same trust as writing the app's defaults with `defaults write`.
@MainActor
final class AIReceiver: NSObject {
    static let shared = AIReceiver()

    func start() {
        // Delivered at once: Ankey is never the active app, and a background app would otherwise get the request
        // only when it next became active.
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(received(_:)), name: Notification.Name(Gateway.requestName), object: nil,
            suspensionBehavior: .deliverImmediately)
    }

    @objc private func received(_ note: Notification) {
        guard let info = note.userInfo as? [String: String], let message = GatewayMessage(userInfo: info) else { return }
        let reply = serve(message)
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name(Gateway.replyName), object: nil, userInfo: reply.userInfo, deliverImmediately: true)
    }

    private func serve(_ message: GatewayMessage) -> GatewayReply {
        func reply(_ ok: Bool, _ text: String, json: String? = nil) -> GatewayReply {
            GatewayReply(id: message.id, ok: ok, message: text, json: json)
        }
        switch message.request {
        case .adjust(let word, let score):
            // `AdjustStore` drops a word the built-in lists do not know as English, so say so instead of
            // reporting a write that was thrown away.
            guard score == 0 || English.knows(word) else {
                return reply(false, "\"\(word)\" is not a word Ankey knows as English, so there is no English side to adjust.")
            }
            guard score != 0 || AdjustStore.shared.words[word] != nil else {
                return reply(false, "\"\(word)\" has no learned score to forget.")
            }
            AdjustStore.shared.set(word, to: score)
            return reply(true, score == 0 ? "Forgot \"\(word)\"." : "\"\(word)\" now has the score \(score).")
        case .forgetPhrase(let prefix, let word):
            let before = PersonalPhrasesStore.shared.learned(limit: Int.max).count
            PersonalPhrasesStore.shared.forget(prefix: prefix, word: word)
            guard PersonalPhrasesStore.shared.learned(limit: Int.max).count < before else {
                return reply(false, "No learned phrase \"\(prefix)\" followed by \"\(word)\". `Ankey show learned` lists them.")
            }
            return reply(true, "Forgot \"\(word)\" after \"\(prefix)\".")
        case .forgetHabit(let word):
            let before = LanguageHabitsStore.shared.learned(limit: Int.max).count
            LanguageHabitsStore.shared.forget(word)
            guard LanguageHabitsStore.shared.learned(limit: Int.max).count < before else {
                return reply(false, "No learned language habit for \"\(word)\". `Ankey show learned` lists them.")
            }
            return reply(true, "Forgot the language habit for \"\(word)\".")
        case .diaryClear:
            DiaryStore.shared.forgetAll()
            return reply(true, "The diary is empty.")
        case .snapshot(let limit):
            let report = AIReport.snapshot(
                adjust: AdjustStore.shared.words,
                phrases: PersonalPhrasesStore.shared.learned(limit: limit),
                habits: LanguageHabitsStore.shared.learned(limit: limit),
                diary: DiaryStore.shared.snapshot(),
                limit: limit,
                source: "live")
            return reply(true, "ok", json: AIJSON.text(report))
        }
    }
}
