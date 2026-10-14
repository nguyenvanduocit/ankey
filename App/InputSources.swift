import Carbon
import Foundation

/// What macOS says about Ankey in the input source list. Ankey is found by the bundle ID in Info.plist.
enum InputSources {
    static func status() -> InputSourceStatus {
        guard let bundleID = Bundle.main.bundleIdentifier else { return .notListed }
        let filter = [kTISPropertyBundleID as String: bundleID] as CFDictionary
        let sources = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] ?? []
        return InputSourceStatus(enabledFlags: sources.map { flag($0, kTISPropertyInputSourceIsEnabled) })
    }

    /// Ankey is the input source in use right now.
    static func isSelected() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(current, kTISPropertyBundleID)
        else { return false }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String == bundleID
    }

    private static func flag(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue())
    }
}
