import Foundation

/// Where Ankey stands in System Settings → Keyboard → Input Sources.
enum InputSourceStatus: Equatable {
    /// macOS lists Ankey and it is switched on.
    case enabled
    /// macOS lists Ankey and it is switched off.
    case disabled
    /// macOS does not list Ankey. A new install shows up only after a logout or restart.
    case notListed

    /// `enabledFlags` holds one entry for each input source macOS lists for Ankey.
    init(enabledFlags: [Bool]) {
        if enabledFlags.isEmpty {
            self = .notListed
        } else {
            self = enabledFlags.contains(true) ? .enabled : .disabled
        }
    }
}

enum Onboarding {
    /// The guide opens by itself once, on a fresh install. An install that already stored values is an
    /// update: the guide waits in the input menu and does not interrupt a person who already types with Ankey.
    static func opensAtLaunch(seen: Bool, hadStoredValues: Bool) -> Bool {
        !seen && !hadStoredValues
    }
}
