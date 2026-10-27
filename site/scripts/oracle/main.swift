// Types each stdin line key by key into the real Session and prints the text the app would commit.
// Compiled with Core/*.swift by engine.test.ts, which compares the output with public/engine.js.
import Foundation

let settings = Settings()
while let line = readLine() {
    var session = Session()
    var out = ""
    for ch in line {
        switch session.push(ch) {
        case .consumed, .flush, .cheat:
            break
        case .pass:
            out.append(ch)
        case .commit:
            out += session.finish(settings)
            out.append(ch)
        }
    }
    out += session.finish(settings)
    print(out)
}
