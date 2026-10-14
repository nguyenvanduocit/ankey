import Foundation

// Reads one typed word per line from stdin and prints `raw<TAB>output` for every word
// the engine changes. Words that come back unchanged are not interesting to the judge.
while let line = readLine() {
    let raw = line.trimmingCharacters(in: .whitespaces).lowercased()
    guard !raw.isEmpty else { continue }
    let out = Engine.render(raw)
    if out != raw { print("\(raw)\t\(out)") }
}
