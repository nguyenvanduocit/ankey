import Cocoa
import SwiftUI

/// Every change writes straight to UserDefaults. The input controller reads it on the next key.
final class SettingsModel: ObservableObject {
    @Published var value = Settings.load() {
        didSet { value.save() }
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        TabView {
            GeneralTab(model: model)
                .tabItem { Label("Chung", systemImage: "gearshape") }
            MacrosTab(model: model)
                .tabItem { Label("Gõ tắt", systemImage: "text.badge.plus") }
            AppsTab(model: model)
                .tabItem { Label("Ứng dụng", systemImage: "app.badge") }
            UpdatesTab()
                .tabItem { Label("Cập nhật", systemImage: "arrow.down.circle") }
        }
        .frame(width: 520, height: 440)
    }
}

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private let model = SettingsModel()

    init() {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
        window.title = "Cài đặt Ankey"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        model.value = Settings.load()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
    }
}
