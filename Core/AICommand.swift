import Foundation

enum ShowTopic: String {
    case all, settings, learned, stats, diary, changes
}

/// A request only the running app can serve, because it owns what the key path keeps in memory.
enum GatewayRequest: Equatable {
    case adjust(word: String, score: Int)
    case forgetPhrase(prefix: String, word: String)
    case forgetHabit(word: String)
    case diaryClear
    case snapshot(limit: Int)
}

/// What one line of the command line asks for.
enum AICommand: Equatable {
    case guide, skill, help
    case show(ShowTopic, limit: Int)
    case edit(ConfigEdit, dryRun: Bool)
    case undo
    case gateway(GatewayRequest)

    static let defaultLimit = 200
    static let limits = 1...2000

    private static let verbs: Set<String> = ["guide", "skill", "help", "show", "set", "shorthand", "app", "learned", "diary", "undo"]

    /// Whether the first argument is a command, so the process is the command line and not the input method.
    static func isVerb(_ argument: String?) -> Bool {
        guard let argument else { return false }
        return verbs.contains(argument) || argument == "--help" || argument == "-h"
    }

    static let usage = """
        Usage: Ankey <command>
          guide                                          instructions for an AI: what each command does
          show [all|settings|learned|stats|diary|changes] [--limit N]
          set <key> <value> [--dry-run]
          shorthand add|remove <word> [--dry-run]
          app set <bundleID> off|marked|direct [--dry-run]
          app remove <bundleID> [--dry-run]
          learned adjust <word> <-2..2>
          learned forget-phrase <prefix> <word>
          learned forget-habit <word>
          diary clear
          undo
          skill                                          a SKILL.md for Claude Code
          help
        """

    static func parse(_ args: [String]) -> Result<AICommand, AIError> {
        guard let verb = args.first else { return .failure(.usage(usage)) }
        let operands: Operands
        switch Operands.split(args.dropFirst()) {
        case .success(let split): operands = split
        case .failure(let error): return .failure(error)
        }
        let words = operands.words
        func failure(_ text: String) -> Result<AICommand, AIError> { .failure(.usage(text)) }
        /// A command with no operand and no option.
        func bare(_ command: AICommand) -> Result<AICommand, AIError> {
            words.isEmpty && !operands.dryRun && operands.limit == nil ? .success(command) : failure("Usage: Ankey \(verb)")
        }
        /// The edit commands accept `--dry-run` and nothing else.
        func editing(_ change: ConfigEdit, usage: String) -> Result<AICommand, AIError> {
            operands.limit == nil ? .success(.edit(change, dryRun: operands.dryRun)) : failure(usage)
        }

        switch verb {
        case "guide": return bare(.guide)
        case "skill": return bare(.skill)
        case "help", "--help", "-h": return bare(.help)
        case "undo": return bare(.undo)
        case "show":
            let topic = words.isEmpty ? ShowTopic.all : ShowTopic(rawValue: words[0])
            guard words.count <= 1, !operands.dryRun, let topic else {
                return failure("Usage: Ankey show [all|settings|learned|stats|diary|changes] [--limit N]")
            }
            return .success(.show(topic, limit: min(max(operands.limit ?? defaultLimit, limits.lowerBound), limits.upperBound)))
        case "set":
            let text = "Usage: Ankey set <key> <value> [--dry-run]"
            guard words.count == 2 else { return failure(text) }
            return editing(ConfigEdit(kind: .set, key: words[0], value: words[1]), usage: text)
        case "shorthand":
            let text = "Usage: Ankey shorthand add|remove <word> [--dry-run]"
            guard words.count == 2, let kind: ConfigEdit.Kind = ["add": .shorthandAdd, "remove": .shorthandRemove][words[0]] else {
                return failure(text)
            }
            return editing(ConfigEdit(kind: kind, key: words[1]), usage: text)
        case "app":
            let text = "Usage: Ankey app set <bundleID> off|marked|direct [--dry-run] | Ankey app remove <bundleID> [--dry-run]"
            if words.count == 3, words[0] == "set" { return editing(ConfigEdit(kind: .appRule, key: words[1], value: words[2]), usage: text) }
            if words.count == 2, words[0] == "remove" { return editing(ConfigEdit(kind: .appRuleRemove, key: words[1]), usage: text) }
            return failure(text)
        case "learned": return learned(words, operands)
        case "diary":
            return words == ["clear"] && !operands.dryRun && operands.limit == nil ? .success(.gateway(.diaryClear)) : failure("Usage: Ankey diary clear")
        default:
            return failure(usage)
        }
    }

    private static func learned(_ words: [String], _ operands: Operands) -> Result<AICommand, AIError> {
        let text = "Usage: Ankey learned adjust <word> <-2..2> | forget-phrase <prefix> <word> | forget-habit <word>"
        guard !operands.dryRun, operands.limit == nil, let action = words.first else { return .failure(.usage(text)) }
        let rest = words.dropFirst().map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !rest.contains(where: \.isEmpty) else { return .failure(.usage(text)) }
        switch (action, rest.count) {
        case ("adjust", 2):
            guard let score = Int(rest[1]), AdjustStore.range.contains(score) else {
                return .failure(.usage("Usage: Ankey learned adjust <word> <score>, a whole number from \(AdjustStore.range.lowerBound) to \(AdjustStore.range.upperBound). 0 forgets the word."))
            }
            return .success(.gateway(.adjust(word: rest[0].lowercased(), score: score)))
        case ("forget-phrase", 2): return .success(.gateway(.forgetPhrase(prefix: rest[0], word: rest[1])))
        case ("forget-habit", 1): return .success(.gateway(.forgetHabit(word: rest[0])))
        default: return .failure(.usage(text))
        }
    }
}

/// The words and options of a command line, apart.
private struct Operands {
    var words: [String] = []
    var dryRun = false
    var limit: Int?

    static func split(_ args: ArraySlice<String>) -> Result<Operands, AIError> {
        var result = Operands()
        var index = args.startIndex
        while index < args.endIndex {
            let arg = args[index]
            if arg == "--dry-run" {
                result.dryRun = true
            } else if arg == "--limit" {
                index += 1
                guard index < args.endIndex, let number = Int(args[index]) else { return .failure(.usage("--limit takes a whole number.")) }
                result.limit = number
            } else if arg.hasPrefix("--") {
                return .failure(.usage("Unknown option \(arg)."))
            } else {
                result.words.append(arg)
            }
            index += 1
        }
        return .success(result)
    }
}

// MARK: - The gateway

/// Names of the two `DistributedNotificationCenter` notifications between the command line and the running app.
enum Gateway {
    static let requestName = "dev.firegroup.inputmethod.Ankey.ai.request"
    static let replyName = "dev.firegroup.inputmethod.Ankey.ai.reply"
}

/// A request and the ID its reply carries back. `userInfo` holds only strings, which every process can read.
struct GatewayMessage: Equatable {
    var id: String
    var request: GatewayRequest

    var userInfo: [String: String] {
        var info = ["id": id]
        switch request {
        case .adjust(let word, let score):
            info["name"] = "adjust"
            info["word"] = word
            info["score"] = String(score)
        case .forgetPhrase(let prefix, let word):
            info["name"] = "forgetPhrase"
            info["prefix"] = prefix
            info["word"] = word
        case .forgetHabit(let word):
            info["name"] = "forgetHabit"
            info["word"] = word
        case .diaryClear:
            info["name"] = "diaryClear"
        case .snapshot(let limit):
            info["name"] = "snapshot"
            info["limit"] = String(limit)
        }
        return info
    }
}

extension GatewayMessage {
    /// Nil for anything that is not a well-formed request, so the app ignores what it does not understand.
    init?(userInfo info: [String: String]) {
        guard let id = info["id"], let name = info["name"] else { return nil }
        let request: GatewayRequest
        switch name {
        case "adjust":
            guard let word = info["word"], let score = info["score"].flatMap(Int.init), AdjustStore.range.contains(score) else { return nil }
            request = .adjust(word: word, score: score)
        case "forgetPhrase":
            guard let prefix = info["prefix"], let word = info["word"] else { return nil }
            request = .forgetPhrase(prefix: prefix, word: word)
        case "forgetHabit":
            guard let word = info["word"] else { return nil }
            request = .forgetHabit(word: word)
        case "diaryClear":
            request = .diaryClear
        case "snapshot":
            guard let limit = info["limit"].flatMap(Int.init), AICommand.limits.contains(limit) else { return nil }
            request = .snapshot(limit: limit)
        default:
            return nil
        }
        self.init(id: id, request: request)
    }
}

/// The app's answer to one request. `json` carries data for a snapshot.
struct GatewayReply: Equatable {
    var id: String
    var ok: Bool
    var message: String
    var json: String?

    var userInfo: [String: String] {
        var info = ["id": id, "ok": ok ? "true" : "false", "message": message]
        if let json { info["json"] = json }
        return info
    }
}

extension GatewayReply {
    init?(userInfo info: [String: String]) {
        guard let id = info["id"], let ok = info["ok"].flatMap({ ["true": true, "false": false][$0] }), let message = info["message"] else {
            return nil
        }
        self.init(id: id, ok: ok, message: message, json: info["json"])
    }
}
