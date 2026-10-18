import Foundation

// Packs the phrase list into the index the app reads: mkphrases <phrases.txt> <phrases.idx>
guard CommandLine.arguments.count == 3,
      let list = try? String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8) else {
    fputs("usage: mkphrases <phrases.txt> <phrases.idx>\n", stderr)
    exit(2)
}
let index = PhraseIndex.build(lines: list.split(separator: "\n"))
guard PhraseIndex(data: index) != nil else {
    fputs("mkphrases: the index it built does not read back\n", stderr)
    exit(1)
}
do {
    try index.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
} catch {
    fputs("mkphrases: \(error.localizedDescription)\n", stderr)
    exit(1)
}
