import Cocoa
import SwiftUI

/// Every change writes straight to UserDefaults. The input controller reads it on the next key. Only the keys
/// that changed are written, so a window left open does not take back what the command line changed.
final class SettingsModel: ObservableObject {
    @Published var value = Settings.load() {
        didSet { value.save(replacing: oldValue) }
    }
    @Published var tab = SettingsTab.general

    /// The window is built once and shown again, and the command line may have changed settings since: read them
    /// again whenever the window comes forward.
    func reload() {
        let fresh = Settings.load()
        if fresh != value { value = fresh }
    }
}

enum SettingsTab: CaseIterable {
    case general, apps, ai, stats, updates

    var title: String {
        switch self {
        case .general: return "Chung"
        case .apps: return "Ứng dụng"
        case .ai: return "AI"
        case .stats: return "Thống kê"
        case .updates: return "Cập nhật"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2 * Pixel.unit) {
                ForEach(SettingsTab.allCases, id: \.self) { item in
                    Button { model.tab = item } label: {
                        Text(item.title).lineLimit(1).minimumScaleFactor(0.85).frame(maxWidth: .infinity)
                    }
                    // Six tabs share the width, so a tab is only as wide as its title needs.
                    .buttonStyle(PixelButtonStyle(primary: model.tab == item, minWidth: 0))
                }
            }
            .padding(.horizontal, 8 * Pixel.unit)
            .padding(.top, Pixel.unit)
            .padding(.bottom, 4 * Pixel.unit)

            switch model.tab {
            case .general: GeneralTab(model: model)
            case .apps: AppsTab(model: model)
            case .ai: AITab(model: model)
            case .stats: StatsTab(model: model)
            case .updates: UpdatesTab()
            }
        }
        .font(Pixel.font())
        .foregroundStyle(Pixel.text)
        .frame(width: 520, height: 440)
        .background(Pixel.bg)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in model.reload() }
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

    func show(tab: SettingsTab? = nil) {
        model.reload()
        if let tab { model.tab = tab }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
    }
}
