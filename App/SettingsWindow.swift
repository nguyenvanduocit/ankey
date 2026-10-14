import Cocoa
import SwiftUI

/// Every change writes straight to UserDefaults. The input controller reads it on the next key.
final class SettingsModel: ObservableObject {
    @Published var value = Settings.load() {
        didSet { value.save() }
    }
}

enum SettingsTab: CaseIterable {
    case general, macros, apps, updates

    var title: String {
        switch self {
        case .general: return "Chung"
        case .macros: return "Gõ tắt"
        case .apps: return "Ứng dụng"
        case .updates: return "Cập nhật"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @State private var tab = SettingsTab.general

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2 * Pixel.unit) {
                ForEach(SettingsTab.allCases, id: \.self) { item in
                    Button { tab = item } label: {
                        Text(item.title).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelButtonStyle(primary: tab == item))
                }
            }
            .padding(.horizontal, 8 * Pixel.unit)
            .padding(.top, 4 * Pixel.unit)

            switch tab {
            case .general: GeneralTab(model: model)
            case .macros: MacrosTab(model: model)
            case .apps: AppsTab(model: model)
            case .updates: UpdatesTab()
            }
        }
        .font(Pixel.font())
        .foregroundStyle(Pixel.text)
        .frame(width: 520, height: 440)
        .background(Pixel.bg)
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
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(Pixel.bg)
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
