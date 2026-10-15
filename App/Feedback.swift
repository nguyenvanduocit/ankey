import Foundation

extension FeedbackContext {
    /// This Mac, with the mode of the app the user is typing in. Never the app itself.
    static func current(mode: AppMode) -> FeedbackContext {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return FeedbackContext(
            macOS: "\(os.majorVersion).\(os.minorVersion)",
            chip: chipName,
            mode: mode
        )
    }

    private static var chipName: String {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else { return "unknown" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0) == 0 else { return "unknown" }
        return String(cString: buffer)
    }
}

/// Why a send failed, in words the user can read in the HUD.
func feedbackFailureMessage(_ error: Error) -> String {
    if let failure = error as? DatadogLogSender.Failure {
        switch failure {
        case .notConfigured: return "bản này chưa có nơi nhận"
        case .rejected(let status): return "máy chủ từ chối (mã \(status))"
        }
    }
    if let failure = error as? URLError {
        switch failure.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: return "không có mạng"
        case .timedOut: return "quá thời gian chờ"
        default: return "không kết nối được"
        }
    }
    return "lỗi không rõ"
}
