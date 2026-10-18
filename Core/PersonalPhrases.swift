import Foundation

/// What Ankey learns from the words the user types: a prefix of up to three words and the words that follow it,
/// counted within a fixed budget. It suggests only where the user's own text agrees with itself.
///
/// The budget is the point. Every typed pair is a candidate and almost all of them happen once, so:
///   - a pair enters the table only when it is seen a second time. A direct-mapped table of pair hashes
///     (`seen`, 128 KB) remembers the first sighting; a newer pair overwrites an older one in the same slot;
///   - the table holds at most `maxNodes` prefixes of at most `maxNexts` following words each. Past the cap the
///     lowest scores go, a tenth of the table at a time so the cost is spread over many words;
///   - a score is the count of occurrences halved every `halfLife` days of not being seen, and the counts
///     themselves decay the same way when a prefix is touched, so old habits give way to new ones;
///   - a pair the shared phrase list already predicts is not stored, which leaves the room for what only this
///     user writes: names, projects, jargon.
struct PersonalPhrases: Codable, Equatable {
    static let maxNodes = 6000
    static let maxNexts = 4
    static let maxContext = 3
    static let maxChain = 4
    static let maxWordLength = 24
    static let seenSlots = 32_768
    static let halfLife = 45.0
    /// Every occurrence of a prefix also scales its counts by this, so a node holds about the last
    /// `1 / (1 - observationDecay)` occurrences however many it has seen: a habit that changes is relearned in
    /// tens of uses, not in as many as it was learned in.
    static let observationDecay = 0.97
    /// A word that follows a prefix at least this often, and in this share of its occurrences, is suggested.
    static let minCount = 2.5
    static let share = 0.8
    /// The most a prefix's score counts its leading word: frequency alone does not keep a prefix.
    static let countCap = 50.0
    /// Past the cap the table drops to this share of it.
    static let evictTo = 0.9

    struct Node: Codable, Equatable {
        /// What follows, by word key, with the word as typed and its decayed count.
        var nexts: [String: Next] = [:]
        /// Occurrences of the prefix followed by something that was not kept.
        var noise = 0.0
        var day: Int

        struct Next: Codable, Equatable {
            var word: String
            var count: Double
        }

        var total: Double { nexts.values.reduce(noise) { $0 + $1.count } }

        /// How much keeping this prefix is worth: what its leading word has been seen, capped, times the square
        /// of that word's share. A prefix everything follows (`có`, `không`) is worth nothing however often it
        /// is typed, because it will never be sure of one word; a name that is always followed by the same
        /// word is worth keeping from its third sighting.
        func score(on today: Int) -> Double {
            guard let best = nexts.values.max(by: { $0.count < $1.count }) else { return 0 }
            let share = best.count / total
            return min(best.count * PersonalPhrases.decay(days: today - day), PersonalPhrases.countCap) * share * share
        }

        mutating func fade(to today: Int) {
            let factor = PersonalPhrases.decay(days: today - day) * PersonalPhrases.observationDecay
            for key in nexts.keys { nexts[key]?.count *= factor }
            noise *= factor
            day = today
        }
    }

    private(set) var nodes: [String: Node] = [:]
    private var seen = [UInt32](repeating: 0, count: PersonalPhrases.seenSlots)

    init() {}

    private enum CodingKeys: String, CodingKey {
        case nodes, seen
    }

    /// The table of first sightings goes to disk as bytes, not as a list of numbers.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nodes = try container.decode([String: Node].self, forKey: .nodes)
        let bytes = try container.decode(Data.self, forKey: .seen)
        if bytes.count == Self.seenSlots * 4 {
            seen = (0..<Self.seenSlots).map { slot in
                bytes.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: slot * 4, as: UInt32.self)) }
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodes, forKey: .nodes)
        var bytes = Data(capacity: seen.count * 4)
        for value in seen { withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) } }
        try container.encode(bytes, forKey: .seen)
    }

    var isEmpty: Bool { nodes.isEmpty }

    static func decay(days: Int) -> Double {
        days <= 0 ? 1 : pow(0.5, Double(days) / halfLife)
    }

    // MARK: - Learning

    /// The user typed `word` after `context`, the words before it in the same run. `covered` says the shared list
    /// already suggests exactly this word there, so there is nothing to learn.
    mutating func observe(context: [String], word: String, covered: Bool, today: Int) {
        let word = word.lowercased()
        guard !covered, Self.learnable(word) else { return }
        let words = context.suffix(Self.maxContext).map { $0.lowercased() }
        guard !words.isEmpty, words.allSatisfy(Self.learnable) else { return }
        // Contexts of every length, the longest first, each counted on its own.
        for length in 1...words.count {
            let prefix = words.suffix(length).map(Suggest.key).joined(separator: " ")
            count(prefix: prefix, word: word, today: today)
        }
        if nodes.count > Self.maxNodes { evict(today: today) }
    }

    /// A word of letters only, short enough to be a word: numbers, codes and tokens are not learned.
    static func learnable(_ word: String) -> Bool {
        !word.isEmpty && word.count <= maxWordLength && word.allSatisfy { $0.isLetter }
    }

    private mutating func count(prefix: String, word: String, today: Int) {
        let key = Suggest.key(word)
        if var node = nodes[prefix] {
            node.fade(to: today)
            if remember(prefix, key) {
                admit(&node, key: key, word: word)
            } else {
                node.noise += 1
            }
            node.day = today
            nodes[prefix] = node
        } else if remember(prefix, key) {
            var node = Node(day: today)
            admit(&node, key: key, word: word)
            nodes[prefix] = node
        }
    }

    /// True when this pair was seen before. Otherwise it is noted, over whatever shared its slot.
    private mutating func remember(_ prefix: String, _ key: String) -> Bool {
        let hash = Self.hash(prefix + "\u{1}" + key)
        let slot = Int(hash % UInt32(Self.seenSlots))
        if seen[slot] == hash { return true }
        seen[slot] = hash
        return false
    }

    /// The second sighting counts as two occurrences. A full node lets a newcomer in only over a weak entry
    /// (two occurrences or so); the entry's count stays in the node as noise, so shares stay honest. A
    /// newcomer never inherits a count it did not earn: a word seen twice must not look as common as the one it
    /// displaced.
    private func admit(_ node: inout Node, key: String, word: String) {
        if node.nexts[key] != nil {
            node.nexts[key]?.count += 1
        } else if node.nexts.count < Self.maxNexts {
            node.nexts[key] = Node.Next(word: word, count: 2)
        } else if let (weakest, entry) = node.nexts.min(by: { $0.value.count < $1.value.count }), entry.count < 3 {
            node.nexts[weakest] = nil
            node.noise += entry.count
            node.nexts[key] = Node.Next(word: word, count: 2)
        } else {
            node.noise += 1
        }
    }

    private mutating func evict(today: Int) {
        let keep = Int(Double(Self.maxNodes) * Self.evictTo)
        let scored = nodes.map { (prefix: $0.key, score: $0.value.score(on: today)) }.sorted { $0.score < $1.score }
        for entry in scored.prefix(nodes.count - keep) { nodes[entry.prefix] = nil }
    }

    /// FNV-1a over the UTF-8 bytes. Stable between launches, which Swift's `Hasher` is not.
    static func hash(_ text: String) -> UInt32 {
        var value: UInt32 = 2_166_136_261
        for byte in text.utf8 {
            value ^= UInt32(byte)
            value = value &* 16_777_619
        }
        return value == 0 ? 1 : value
    }

    // MARK: - Suggesting

    /// The words the user's own text agrees on after `words`, as the user wrote them, or nil.
    func certain(after words: [String], today: Int) -> [String]? {
        var typed = words.map { $0.lowercased() }
        var chain: [String] = []
        while chain.count < Self.maxChain, let next = following(typed, today: today) {
            chain.append(next)
            typed.append(next)
        }
        return chain.isEmpty ? nil : chain
    }

    /// The word that follows the last words: from the longest prefix that has seen enough, and only if one word
    /// has most of its occurrences. A prefix that has seen too little defers to a shorter one.
    private func following(_ words: [String], today: Int) -> String? {
        for length in stride(from: min(Self.maxContext, words.count), through: 1, by: -1) {
            let prefix = words.suffix(length).map(Suggest.key).joined(separator: " ")
            guard let node = nodes[prefix] else { continue }
            let factor = Self.decay(days: today - node.day)
            let total = node.total * factor
            guard total >= Self.minCount else { continue }
            guard let best = node.nexts.values.max(by: { $0.count < $1.count }) else { return nil }
            let count = best.count * factor
            return count >= Self.minCount && count / total >= Self.share ? best.word : nil
        }
        return nil
    }

    // MARK: - Reading what was learned

    /// What the user can read and remove: each prefix and word that Ankey would suggest, most used first.
    func learned(today: Int, limit: Int) -> [(prefix: String, word: String, count: Int)] {
        nodes.compactMap { prefix, node in
            guard let best = node.nexts.values.max(by: { $0.count < $1.count }) else { return nil }
            let factor = Self.decay(days: today - node.day)
            let count = best.count * factor
            guard count >= Self.minCount, count / (node.total * factor) >= Self.share else { return nil }
            return (prefix: prefix, word: best.word, count: Int(count.rounded()))
        }
        .sorted { $0.count > $1.count }
        .prefix(limit).map { $0 }
    }

    /// Removes the word after the prefix, and after every longer or shorter prefix that ends the same way, so
    /// a suggestion the user deleted does not come back through a context of another length.
    mutating func forget(prefix: String, word: String) {
        let key = Suggest.key(word)
        func related(_ other: String) -> Bool {
            other == prefix || prefix.hasSuffix(" " + other) || other.hasSuffix(" " + prefix)
        }
        for other in nodes.keys where related(other) {
            nodes[other]?.nexts[key] = nil
            if nodes[other]?.nexts.isEmpty == true { nodes[other] = nil }
        }
    }

    mutating func forgetAll() {
        self = PersonalPhrases()
    }
}
