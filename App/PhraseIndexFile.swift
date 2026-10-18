import Foundation

extension PhraseIndex {
    /// The index packed into the app at build time, mapped rather than read: only the pages a lookup touches
    /// come into memory. Nil when the file is missing, which turns suggestions off.
    static let bundled: PhraseIndex? = {
        guard let url = Bundle.main.url(forResource: "phrases", withExtension: "idx"),
              let data = try? Data(contentsOf: url, options: .alwaysMapped) else { return nil }
        return PhraseIndex(data: data)
    }()
}
