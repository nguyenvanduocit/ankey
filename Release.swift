import Foundation

/// The GitHub repo that publishes Ankey releases.
let releaseRepo = "nguyenvanduocit/ankey"

/// A dotted version such as `1.2.3`. Missing trailing parts count as zero.
struct Version: Comparable {
    let parts: [Int]

    init?(_ string: String) {
        let text = string.hasPrefix("v") ? String(string.dropFirst()) : string
        let numbers = text.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !numbers.isEmpty, !numbers.contains(nil) else { return nil }
        parts = numbers.compactMap { $0 }
    }

    var text: String { parts.map(String.init).joined(separator: ".") }

    private func padded(to count: Int) -> [Int] {
        parts + Array(repeating: 0, count: max(0, count - parts.count))
    }

    static func == (lhs: Version, rhs: Version) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        return lhs.padded(to: count) == rhs.padded(to: count)
    }

    static func < (lhs: Version, rhs: Version) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        return lhs.padded(to: count).lexicographicallyPrecedes(rhs.padded(to: count))
    }
}

/// What the updater needs from a GitHub release.
struct ReleaseInfo {
    let version: Version
    let notes: String
    let zipURL: URL
    let checksumURL: URL
}

extension ReleaseInfo {
    private struct Payload: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: String
        }
        let tag_name: String
        let body: String?
        let assets: [Asset]
    }

    /// Reads the `releases/latest` reply. Returns nil unless the tag is a version and the
    /// release carries `Ankey-*.zip` plus its `.sha256`, both hosted by this repo.
    static func parse(json: Data) -> ReleaseInfo? {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: json),
              let version = Version(payload.tag_name)
        else { return nil }
        func asset(where matches: (String) -> Bool) -> URL? {
            payload.assets
                .first { $0.name.hasPrefix("Ankey-") && matches($0.name) }
                .flatMap { URL(string: $0.browser_download_url) }
                .flatMap(releaseAssetURL)
        }
        guard let zip = asset(where: { $0.hasSuffix(".zip") }),
              let checksum = asset(where: { $0.hasSuffix(".zip.sha256") })
        else { return nil }
        return ReleaseInfo(version: version, notes: payload.body ?? "", zipURL: zip, checksumURL: checksum)
    }

    private static func releaseAssetURL(_ url: URL) -> URL? {
        guard url.scheme == "https", url.host == "github.com",
              url.path.hasPrefix("/\(releaseRepo)/releases/download/")
        else { return nil }
        return url
    }
}

/// The hex digest from a `shasum` line (`<digest>  <file>`), lowercased.
func parseChecksum(_ text: String) -> String? {
    guard let token = text.split(whereSeparator: \.isWhitespace).first else { return nil }
    let digest = token.lowercased()
    guard digest.count == 64, digest.allSatisfy(\.isHexDigit) else { return nil }
    return digest
}
