import Foundation

/// Phrases packed for lookup: a radix tree over syllables, written once when the app is built and read in
/// place from the mapped file, so starting Ankey parses nothing and the pages nobody asks about stay on disk.
///
/// Layout, little endian: eight `UInt32` header words (magic, version, syllable count, node count, label
/// count, key bytes, text bytes, spare), then these sections, each padded to four bytes:
///   - key offsets and text offsets, `syllables + 1` words each, into the two byte blobs;
///   - the key blob: every distinct syllable compared without tone placement (`Suggest.key`), sorted by bytes,
///     so a typed syllable finds its number by binary search;
///   - the text blob: the same syllables as written, which is what a suggestion shows;
///   - labels, `UInt16` syllable numbers, the edges of the tree laid end to end;
///   - nodes, 12 bytes each: label offset, first child (`UInt32`), label length, child count (`UInt16`; the top
///     bit marks a phrase that ends at the node). A node's children sit side by side, sorted by first syllable.
///     Node 0 is the root.
/// An edge ends where phrases split or one ends, so the syllables left on an edge are the ones every phrase
/// through it agrees on.
struct PhraseIndex {
    private static let magic: UInt32 = 0x504B_4E41
    private static let version: UInt32 = 1
    private static let headerWords = 8
    private static let nodeSize = 12
    private static let ends = 0x8000

    private let data: Data
    private let syllableCount: Int
    private let keyOffsets: Int
    private let textOffsets: Int
    private let keyBlob: Int
    private let textBlob: Int
    private let labels: Int
    private let nodes: Int

    /// The size of the packed index, which the app maps rather than reads.
    var byteCount: Int { data.count }

    /// Nil when the bytes are not an index of this version.
    init?(data: Data) {
        func word(_ index: Int) -> Int? {
            guard data.count >= (index + 1) * 4 else { return nil }
            return Int(data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: index * 4, as: UInt32.self) })
        }
        guard word(0) == Int(Self.magic), word(1) == Int(Self.version),
              let syllables = word(2), let nodeCount = word(3), let labelCount = word(4),
              let keyBytes = word(5), let textBytes = word(6) else { return nil }
        func padded(_ size: Int) -> Int { (size + 3) & ~3 }
        var at = Self.headerWords * 4
        keyOffsets = at
        at += (syllables + 1) * 4
        textOffsets = at
        at += (syllables + 1) * 4
        keyBlob = at
        at += padded(keyBytes)
        textBlob = at
        at += padded(textBytes)
        labels = at
        at += padded(labelCount * 2)
        nodes = at
        at += nodeCount * Self.nodeSize
        guard at == data.count, nodeCount > 0 else { return nil }
        self.data = data
        syllableCount = syllables
    }

    // MARK: - Lookup

    /// The syllables every phrase that continues `words` agrees on next, as the list wrote them, or nil when
    /// there is nothing certain to say: the words are no start of a phrase, end a phrase themselves, or leave
    /// phrases that split right away. The longest run of the last `Suggest.maxWords` words that starts a
    /// phrase decides; a shorter run only adds phrases that start later.
    func certain(after words: [String]) -> [String]? {
        let ids = words.suffix(Suggest.maxWords).map(syllable)
        guard ids.count >= Suggest.minWords else { return nil }
        for start in 0...(ids.count - Suggest.minWords) {
            let run = ids[start...]
            guard !run.contains(where: { $0 == nil }) else { continue }
            if let found = follow(run.map { $0! }) { return found.isEmpty ? nil : found.map(text) }
        }
        return nil
    }

    /// Walks `run` down the tree. Nil when it leaves the tree; otherwise the syllable numbers left on the edge
    /// it stopped on, empty when it stopped at a node that ends a phrase or splits.
    private func follow(_ run: [Int]) -> [Int]? {
        var node = 0
        var at = 0
        while true {
            if at == run.count {
                // Stopped at a node. Only one with a single way on (the root can be) has a rest.
                let (_, _, first, count) = decode(node)
                return flagged(node) || count != 1 ? [] : label(of: first)
            }
            guard let child = child(of: node, starting: run[at]) else { return nil }
            let edge = label(of: child)
            for (offset, syllable) in edge.enumerated() {
                if at + offset == run.count { return Array(edge[offset...]) }
                if run[at + offset] != syllable { return nil }
            }
            at += edge.count
            node = child
        }
    }

    // MARK: - Reading

    private func decode(_ node: Int) -> (labelStart: Int, labelLength: Int, first: Int, count: Int) {
        let at = nodes + node * Self.nodeSize
        let packed = read16(at + 10)
        return (read32(at), read16(at + 8), read32(at + 4), packed & ~Self.ends)
    }

    private func flagged(_ node: Int) -> Bool {
        read16(nodes + node * Self.nodeSize + 10) & Self.ends != 0
    }

    private func label(of node: Int) -> [Int] {
        let (start, length, _, _) = decode(node)
        return (0..<length).map { read16(labels + (start + $0) * 2) }
    }

    /// The child of `node` whose edge starts with `syllable`.
    private func child(of node: Int, starting syllable: Int) -> Int? {
        let (_, _, first, count) = decode(node)
        var low = 0
        var high = count
        while low < high {
            let middle = (low + high) / 2
            let (start, _, _, _) = decode(first + middle)
            let value = read16(labels + start * 2)
            if value == syllable { return first + middle }
            if value < syllable { low = middle + 1 } else { high = middle }
        }
        return nil
    }

    /// The number of a typed syllable, by binary search over the sorted keys.
    private func syllable(_ word: String) -> Int? {
        let key = Array(Suggest.key(word).utf8)
        var low = 0
        var high = syllableCount
        while low < high {
            let middle = (low + high) / 2
            switch compare(key, withKey: middle) {
            case 0: return middle
            case ..<0: high = middle
            default: low = middle + 1
            }
        }
        return nil
    }

    private func compare(_ key: [UInt8], withKey index: Int) -> Int {
        let start = keyBlob + read32(keyOffsets + index * 4)
        let end = keyBlob + read32(keyOffsets + (index + 1) * 4)
        return data.withUnsafeBytes { bytes in
            var position = start
            for byte in key {
                if position == end { return 1 }
                let other = bytes[position]
                if byte != other { return byte < other ? -1 : 1 }
                position += 1
            }
            return position == end ? 0 : -1
        }
    }

    private func text(_ syllable: Int) -> String {
        let start = textBlob + read32(textOffsets + syllable * 4)
        let end = textBlob + read32(textOffsets + (syllable + 1) * 4)
        return data.withUnsafeBytes { String(decoding: $0[start..<end], as: UTF8.self) }
    }

    private func read32(_ offset: Int) -> Int {
        Int(data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) })
    }

    private func read16(_ offset: Int) -> Int {
        Int(data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self) })
    }
}

// MARK: - Building

extension PhraseIndex {
    private final class Trie {
        var next: [Int: Trie] = [:]
        var ends = false
    }

    private struct Packed {
        var label: [Int]
        var ends: Bool
        var first = 0
        var count = 0
    }

    /// The index for `lines`, one phrase each, words split by spaces. Lines of fewer than `Suggest.minWords` words, empty lines
    /// and lines that start with `#` are skipped.
    static func build(lines: [Substring]) -> Data {
        var texts: [String: String] = [:]
        var phrases: [[String]] = []
        for line in lines where !line.hasPrefix("#") {
            let words = line.split(separator: " ").map(String.init)
            guard words.count >= Suggest.minWords else { continue }
            for word in words where texts[Suggest.key(word)] == nil { texts[Suggest.key(word)] = word }
            phrases.append(words.map(Suggest.key))
        }
        let keys = texts.keys.map { Array($0.utf8) }.sorted { $0.lexicographicallyPrecedes($1) }
        var number: [String: Int] = [:]
        for (index, key) in keys.enumerated() { number[String(decoding: key, as: UTF8.self)] = index }

        let root = Trie()
        for phrase in phrases {
            var at = root
            for key in phrase {
                if let next = at.next[number[key]!] {
                    at = next
                } else {
                    let next = Trie()
                    at.next[number[key]!] = next
                    at = next
                }
            }
            at.ends = true
        }

        // Breadth first, so the children of a node sit side by side.
        var packed = [Packed(label: [], ends: false)]
        var work: [(Trie, Int)] = [(root, 0)]
        var head = 0
        while head < work.count {
            let (trie, index) = work[head]
            head += 1
            let kids = trie.next.sorted { $0.key < $1.key }
            packed[index].first = packed.count
            packed[index].count = kids.count
            for (syllable, first) in kids {
                var label = [syllable]
                var tail = first
                while tail.next.count == 1, !tail.ends, let (more, deeper) = tail.next.first {
                    label.append(more)
                    tail = deeper
                }
                packed.append(Packed(label: label, ends: tail.ends))
                work.append((tail, packed.count - 1))
            }
        }

        var out = Data()
        func add32(_ value: Int) { withUnsafeBytes(of: UInt32(value).littleEndian) { out.append(contentsOf: $0) } }
        func add16(_ value: Int) { withUnsafeBytes(of: UInt16(value).littleEndian) { out.append(contentsOf: $0) } }
        func pad() { while out.count % 4 != 0 { out.append(0) } }
        func offsets(of blobs: [[UInt8]]) {
            var total = 0
            for blob in blobs {
                add32(total)
                total += blob.count
            }
            add32(total)
        }
        let shown = keys.map { Array(texts[String(decoding: $0, as: UTF8.self)]!.utf8) }
        let labelCount = packed.reduce(0) { $0 + $1.label.count }
        for value in [Int(magic), Int(version), keys.count, packed.count, labelCount,
                      keys.reduce(0) { $0 + $1.count }, shown.reduce(0) { $0 + $1.count }, 0] { add32(value) }
        offsets(of: keys)
        offsets(of: shown)
        for blob in keys { out.append(contentsOf: blob) }
        pad()
        for blob in shown { out.append(contentsOf: blob) }
        pad()
        for node in packed { for syllable in node.label { add16(syllable) } }
        pad()
        var labelAt = 0
        for node in packed {
            add32(labelAt)
            add32(node.first)
            add16(node.label.count)
            add16(node.count | (node.ends ? ends : 0))
            labelAt += node.label.count
        }
        return out
    }
}
