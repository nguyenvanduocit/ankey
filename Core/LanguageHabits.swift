import Foundation

/// How the user's words follow each other in language: after this word they usually write English, or
/// Vietnamese. Ankey reads it when a word could be either (`as`, `cos`), which the language of the word before
/// it alone cannot settle: the first English word after Vietnamese text has nothing to follow, but it may
/// follow `dùng` or `chạy` nearly every time.
///
/// The table is bounded like `PersonalPhrases`. It keeps at most `maxNodes` previous words, two counts each,
/// and past the cap drops the lowest scores a tenth at a time. A score is the count of samples (capped) times
/// the square of how one-sided they are, halved every `halfLife` days of not being seen, so a word the user
/// follows with both languages equally, which can never decide anything, does not keep its place.
struct LanguageHabits: Codable, Equatable {
    static let maxNodes = 4000
    static let evictTo = 0.9
    static let halfLife = 60.0
    /// Every sample also scales both counts by this, so a node holds about the last `1 / (1 - observationDecay)`
    /// samples and a habit that changes is relearned in tens of words.
    static let observationDecay = 0.97
    static let countCap = 50.0
    /// The samples a word needs, and the share of them in one language, before it leans.
    static let minSamples = 7.0
    static let share = 0.9
    /// A word the user chose by hand (Esc, Shift+Esc, erase and retype) counts for this many samples. A word
    /// whose language was never in doubt counts for one.
    static let chosenWeight = 4.0

    struct Node: Codable, Equatable {
        var english = 0.0
        var vietnamese = 0.0
        var day: Int

        var total: Double { english + vietnamese }

        /// Counts fade the same way when the node is touched, so old habits give way to new ones.
        mutating func fade(to today: Int) {
            let factor = LanguageHabits.decay(days: today - day) * LanguageHabits.observationDecay
            english *= factor
            vietnamese *= factor
            day = today
        }

        func score(on today: Int) -> Double {
            let total = total
            guard total > 0 else { return 0 }
            let certainty = max(english, vietnamese) / total
            return min(total * LanguageHabits.decay(days: today - day), LanguageHabits.countCap) * certainty * certainty
        }
    }

    private(set) var nodes: [String: Node] = [:]
    /// The day `lean` measures ages from, set when a copy is taken for the key path. Not stored.
    var asOf = 0

    init() {}

    private enum CodingKeys: String, CodingKey {
        case nodes
    }

    init(from decoder: Decoder) throws {
        nodes = try decoder.container(keyedBy: CodingKeys.self).decode([String: Node].self, forKey: .nodes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodes, forKey: .nodes)
    }

    var isEmpty: Bool { nodes.isEmpty }

    static func decay(days: Int) -> Double {
        days <= 0 ? 1 : pow(0.5, Double(days) / halfLife)
    }

    // MARK: - Learning

    /// The user's word in `language` came right after `previous`.
    mutating func observe(after previous: String, language: Language, weight: Double, today: Int) {
        let key = Suggest.key(previous)
        guard Self.learnable(key) else { return }
        var node = nodes[key] ?? Node(day: today)
        node.fade(to: today)
        if language == .english { node.english += weight } else { node.vietnamese += weight }
        node.day = today
        nodes[key] = node
        if nodes.count > Self.maxNodes { evict(today: today) }
    }

    /// A word of letters only, short enough to be a word.
    static func learnable(_ key: String) -> Bool {
        !key.isEmpty && key.count <= PersonalPhrases.maxWordLength && key.allSatisfy { $0.isLetter }
    }

    private mutating func evict(today: Int) {
        let keep = Int(Double(Self.maxNodes) * Self.evictTo)
        let scored = nodes.map { (word: $0.key, score: $0.value.score(on: today)) }.sorted { $0.score < $1.score }
        for entry in scored.prefix(nodes.count - keep) { nodes[entry.word] = nil }
    }

    // MARK: - Reading

    /// The language the user nearly always writes after `previous`, or nil.
    func lean(after previous: String?) -> Language? {
        guard let previous, let node = nodes[Suggest.key(previous)] else { return nil }
        let factor = Self.decay(days: asOf - node.day)
        let total = node.total * factor
        guard total >= Self.minSamples else { return nil }
        if node.english * factor / total >= Self.share { return .english }
        if node.vietnamese * factor / total >= Self.share { return .vietnamese }
        return nil
    }

    /// What the user can read and remove: the words that lean, most seen first.
    func learned(limit: Int) -> [(word: String, language: Language, samples: Int)] {
        nodes.compactMap { word, node in
            let factor = Self.decay(days: asOf - node.day)
            let total = node.total * factor
            guard total >= Self.minSamples else { return nil }
            if node.english * factor / total >= Self.share { return (word, .english, Int(total.rounded())) }
            if node.vietnamese * factor / total >= Self.share { return (word, .vietnamese, Int(total.rounded())) }
            return nil
        }
        .sorted { $0.samples > $1.samples }
        .prefix(limit).map { $0 }
    }

    mutating func forget(_ word: String) {
        nodes[Suggest.key(word)] = nil
    }

    mutating func forgetAll() {
        nodes = [:]
    }
}
