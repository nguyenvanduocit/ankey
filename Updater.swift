import Cocoa
import CryptoKit
import Security

/// An update must be signed by the team that signs every Ankey release.
private let signingRequirement = "anchor apple generic and certificate leaf[subject.OU] = \"REDACTED\""

private let validityFlags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)

private let lastCheckKey = "lastUpdateCheck"
private let checkInterval: TimeInterval = 24 * 3600
private let timerInterval: TimeInterval = 3600

enum UpdateError: LocalizedError {
    case noRelease
    case badReply
    case badChecksum
    case checksumMismatch
    case unzipFailed
    case badSignature
    case unexpectedApp
    case notWritable

    var errorDescription: String? {
        switch self {
        case .noRelease: return "Chưa có bản phát hành nào."
        case .badReply: return "GitHub trả về dữ liệu không đọc được."
        case .badChecksum: return "Không đọc được mã kiểm tra của bản tải về."
        case .checksumMismatch: return "Bản tải về bị lỗi, mã kiểm tra không khớp."
        case .unzipFailed: return "Không giải nén được bản tải về."
        case .badSignature: return "Bản tải về không có chữ ký hợp lệ của Ankey."
        case .unexpectedApp: return "Bản tải về không đúng ứng dụng hoặc phiên bản đã công bố."
        case .notWritable: return "Ankey nằm ở thư mục không ghi được, không tự cập nhật."
        }
    }
}

/// Checks GitHub Releases once a day and installs a newer build after the user agrees.
final class Updater: ObservableObject {
    static let shared = Updater()

    enum State {
        case idle
        case checking
        case upToDate
        case available(ReleaseInfo)
        case installing
        case failed(String)
    }

    @Published private(set) var state = State.idle
    @Published private(set) var lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date

    static var currentVersion: Version {
        let text = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return Version(text) ?? Version("0")!
    }

    /// Call once at launch. The timer only runs a check when the last one is a day old.
    func startScheduledChecks() {
        Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
            self.checkIfDue()
        }
        checkIfDue()
    }

    /// A background check keeps quiet on failure. A check the user asked for shows it.
    func check(userInitiated: Bool) {
        let previous = state
        switch previous {
        case .checking, .installing: return
        default: break
        }
        state = .checking
        Task {
            do {
                let release = try await Self.fetchLatest()
                let now = Date()
                UserDefaults.standard.set(now, forKey: lastCheckKey)
                await publish(release.version > Self.currentVersion ? .available(release) : .upToDate, lastCheck: now)
            } catch {
                await publish(userInitiated ? .failed(error.localizedDescription) : previous)
            }
        }
    }

    /// Replaces the running app with the release, then quits so macOS starts the new build.
    func install() {
        guard case .available(let release) = state else { return }
        state = .installing
        Task {
            do {
                try await Self.install(release)
                DispatchQueue.main.async { exit(0) }
            } catch {
                await publish(.failed(error.localizedDescription))
            }
        }
    }

    private func checkIfDue() {
        if let lastCheck, Date().timeIntervalSince(lastCheck) < checkInterval { return }
        check(userInitiated: false)
    }

    private func publish(_ state: State, lastCheck: Date? = nil) async {
        await MainActor.run {
            self.state = state
            if let lastCheck { self.lastCheck = lastCheck }
        }
    }

    // MARK: Network

    private static func fetchLatest() async throws -> ReleaseInfo {
        let url = URL(string: "https://api.github.com/repos/\(releaseRepo)/releases/latest")!
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Ankey/\(currentVersion.text)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 404 { throw UpdateError.noRelease }
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let release = ReleaseInfo.parse(json: data)
        else { throw UpdateError.badReply }
        return release
    }

    // MARK: Install

    /// Every check runs on a copy in a temp directory. The installed app is replaced last.
    private static func install(_ release: ReleaseInfo) async throws {
        let fileManager = FileManager.default
        let installed = Bundle.main.bundleURL
        guard fileManager.isWritableFile(atPath: installed.deletingLastPathComponent().path) else {
            throw UpdateError.notWritable
        }
        let work = fileManager.temporaryDirectory.appendingPathComponent("ankey-update-\(UUID().uuidString)")
        try fileManager.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: work) }

        let zip = work.appendingPathComponent("update.zip")
        let (downloaded, zipResponse) = try await URLSession.shared.download(from: release.zipURL)
        try fileManager.moveItem(at: downloaded, to: zip)
        let (checksumData, checksumResponse) = try await URLSession.shared.data(from: release.checksumURL)
        guard (zipResponse as? HTTPURLResponse)?.statusCode == 200,
              (checksumResponse as? HTTPURLResponse)?.statusCode == 200
        else { throw UpdateError.badReply }

        guard let expected = parseChecksum(String(decoding: checksumData, as: UTF8.self)) else {
            throw UpdateError.badChecksum
        }
        let digest = SHA256.hash(data: try Data(contentsOf: zip, options: .mappedIfSafe))
        guard digest.map({ String(format: "%02x", $0) }).joined() == expected else {
            throw UpdateError.checksumMismatch
        }

        let extracted = work.appendingPathComponent("extracted")
        try unzip(zip, into: extracted)
        let newApp = extracted.appendingPathComponent(installed.lastPathComponent)
        try verifySignature(of: newApp)
        let info = Bundle(url: newApp)?.infoDictionary
        guard info?["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
              (info?["CFBundleShortVersionString"] as? String).flatMap(Version.init) == release.version
        else { throw UpdateError.unexpectedApp }

        _ = try fileManager.replaceItemAt(installed, withItemAt: newApp)
    }

    private static func unzip(_ zip: URL, into directory: URL) throws {
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", zip.path, directory.path]
        try ditto.run()
        ditto.waitUntilExit()
        guard ditto.terminationStatus == 0 else { throw UpdateError.unzipFailed }
    }

    private static func verifySignature(of app: URL) throws {
        var code: SecStaticCode?
        var requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString(signingRequirement as CFString, [], &requirement) == errSecSuccess,
              let requirement,
              SecStaticCodeCheckValidity(code, validityFlags, requirement) == errSecSuccess
        else { throw UpdateError.badSignature }
    }
}
