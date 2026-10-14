import Cocoa
import SwiftUI

/// System Settings → Keyboard. The Input Sources list is a sheet inside it, with no link of its own.
private let keyboardSettingsURL = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!

extension Trigger {
    /// One line for the guide. The switch has no default, so a new cheat code does not build until it has a line.
    var guideText: String {
        switch self {
        case .report(let kind):
            switch kind {
            case .bug: return "Báo lỗi cho tác giả."
            case .feedback: return "Gửi góp ý cho tác giả."
            }
        case .settings:
            return "Mở Cài đặt."
        }
    }
}

struct OnboardingView: View {
    let onFinish: () -> Void

    private static let lastStep = 2
    @State private var step = 0
    @State private var status = InputSources.status()
    @State private var isSelected = InputSources.isSelected()
    @State private var practice = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("HƯỚNG DẪN \(step + 1)/\(Self.lastStep + 1)")
                .font(Pixel.font(16))
                .foregroundStyle(Pixel.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8 * Pixel.unit)
                .padding(.top, Pixel.unit)

            Group {
                switch step {
                case 0: enableStep
                case 1: tryStep
                default: moreStep
                }
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 2 * Pixel.unit) {
                Button("Quay lại") { step -= 1 }
                    .buttonStyle(PixelButtonStyle())
                    .disabled(step == 0)
                Spacer()
                if step < Self.lastStep {
                    Button("Tiếp") { step += 1 }
                        .buttonStyle(PixelButtonStyle(primary: true))
                } else {
                    Button("Xong", action: onFinish)
                        .buttonStyle(PixelButtonStyle(primary: true))
                }
            }
            .padding(.horizontal, 8 * Pixel.unit)
            .padding(.vertical, 5 * Pixel.unit)
        }
        .font(Pixel.font())
        .foregroundStyle(Pixel.text)
        .frame(width: 520, height: 440)
        .background(Pixel.bg)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
    }

    private func refresh() {
        status = InputSources.status()
        isSelected = InputSources.isSelected()
    }

    private var enableStep: some View {
        PixelPage {
            PixelSection(
                title: "1. Bật Ankey",
                footer: "Bộ gõ mới cài có thể chỉ hiện trong danh sách sau khi đăng xuất hoặc khởi động lại máy."
            ) {
                statusRow
                Text("Mở System Settings → Keyboard → Input Sources → Edit… → + → Vietnamese → Ankey → Add.")
                HStack(spacing: 2 * Pixel.unit) {
                    Button("Mở Cài đặt hệ thống") { NSWorkspace.shared.open(keyboardSettingsURL) }
                        .buttonStyle(PixelButtonStyle(primary: status != .enabled))
                    Button("Kiểm tra lại", action: refresh)
                        .buttonStyle(PixelButtonStyle())
                }
            }
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch status {
        case .enabled:
            Text("Ankey đã được bật.").foregroundStyle(Pixel.accent)
        case .disabled:
            Text("Ankey đã cài nhưng chưa bật trong danh sách bộ gõ.").foregroundStyle(Pixel.gold)
        case .notListed:
            Text("Chưa thấy Ankey trong danh sách bộ gõ. Đăng xuất rồi đăng nhập lại, hoặc khởi động lại máy.")
                .foregroundStyle(Pixel.danger)
        }
    }

    private var tryStep: some View {
        PixelPage {
            PixelSection(
                title: "2. Gõ thử",
                footer: "Gõ vieetj ra việt, duwocj ra dược. Gõ test rồi bấm cách, chữ vẫn là test."
            ) {
                if !isSelected {
                    Text("Đang dùng bộ gõ khác. Bấm biểu tượng bộ gõ ở thanh menu trên cùng và chọn Ankey.")
                        .foregroundStyle(Pixel.gold)
                }
                TextField("Gõ thử", text: $practice, prompt: Text("Gõ thử ở đây"))
                    .labelsHidden()
                    .pixelField()
            }
        }
    }

    private var moreStep: some View {
        PixelPage {
            PixelSection(title: "3. Còn gì nữa") {
                Text("Esc trả lại chữ đã gõ: Ankey đã đổi test thành tét thì bấm Esc để về test.")
                Text("Mỗi ứng dụng chọn tắt Ankey, gạch chân hoặc chèn trực tiếp ở thẻ Ứng dụng.")
                Text("Phím tắt và từ viết tắt nằm ở thẻ Gõ tắt.")
            }
            PixelSection(
                title: "Mã gõ nhanh",
                footer: "Gõ mã ở đầu từ rồi làm theo hướng dẫn hiện ra."
            ) {
                ForEach(Trigger.all, id: \.code) { trigger in
                    HStack(alignment: .firstTextBaseline, spacing: 3 * Pixel.unit) {
                        Text(trigger.code).foregroundStyle(Pixel.accent)
                        Text(trigger.guideText).foregroundStyle(Pixel.muted)
                    }
                }
            }
            Button("Mở Cài đặt") { SettingsWindowController.shared.show() }
                .buttonStyle(PixelButtonStyle())
        }
    }
}

final class OnboardingWindowController: NSWindowController {
    static let shared = OnboardingWindowController()

    init() {
        let window = NSWindow()
        window.title = "Hướng dẫn Ankey"
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

    /// Starts again at step 1 every time.
    func show() {
        window?.contentViewController = NSHostingController(rootView: OnboardingView { [weak self] in self?.close() })
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
    }
}
