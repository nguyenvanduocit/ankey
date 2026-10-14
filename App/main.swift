import Cocoa
import InputMethodKit
import Carbon

private let connectionName = "Ankey_Connection"

var ankeyServer: IMKServer!

if CommandLine.arguments.dropFirst().contains("enable") {
    enableAnkey()
    exit(0)
}

Pixel.registerFont()

// NSClassFromString loads the controller by the plist name. Keep the class linked.
_ = AnkeyInputController.self

ankeyServer = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
// The syllable index takes about 20 ms to build. Build it now so the first keystroke does not wait.
_ = Engine.render("as")
// The guide opens once, on a fresh install. Read the stored values before anything below writes one.
let hadStoredValues = !(UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")?.isEmpty ?? true)
let opensGuide = Onboarding.opensAtLaunch(seen: Settings.load().onboardingSeen, hadStoredValues: hadStoredValues)
Settings.markOnboardingSeen()
if opensGuide {
    Task { @MainActor in OnboardingWindowController.shared.show(.firstRun) }
}
Updater.shared.startScheduledChecks()
StatsSchedule.start()
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)

private func enableAnkey() {
    let props = [kTISPropertyBundleID as String: Bundle.main.bundleIdentifier ?? ""] as CFDictionary
    guard let list = TISCreateInputSourceList(props, true)?.takeRetainedValue() else {
        fputs("Input source list is empty.\n", stderr)
        exit(1)
    }
    let sources = list as NSArray
    if sources.count == 0 {
        fputs("Ankey is not registered yet. Add it in System Settings → Keyboard → Input Sources, or log out and back in.\n", stderr)
        exit(1)
    }
    for index in 0..<sources.count {
        let source = OpaquePointer(Unmanaged<CFTypeRef>.passUnretained(sources[index] as CFTypeRef).toOpaque())
        let ref = unsafeBitCast(source, to: TISInputSource.self)
        TISEnableInputSource(ref)
    }
    print("enabled \(sources.count) source(s)")
}
