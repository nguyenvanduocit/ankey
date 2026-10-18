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

/// One row for each cheat code, read from `Trigger.all`.
struct TriggerRows: View {
    var body: some View {
        ForEach(Trigger.all, id: \.code) { trigger in
            HStack(alignment: .firstTextBaseline, spacing: 3 * Pixel.unit) {
                Text(trigger.code).foregroundStyle(Pixel.accent)
                Text(trigger.guideText).foregroundStyle(Pixel.muted)
            }
        }
    }
}

/// The first run walks through setup. Help is for someone who already types with Ankey, so it has no
/// setup check and no practice field.
enum GuideMode {
    case firstRun
    case help

    var title: String {
        switch self {
        case .firstRun: return "Hướng dẫn Ankey"
        case .help: return "Trợ giúp Ankey"
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
                Text("Từ viết tắt như đc nằm ở thẻ Viết tắt.")
            }
            PixelSection(
                title: "Mã gõ nhanh",
                footer: "Gõ mã ở đầu từ rồi làm theo hướng dẫn hiện ra."
            ) {
                TriggerRows()
            }
            Button("Mở Cài đặt") { SettingsWindowController.shared.show() }
                .buttonStyle(PixelButtonStyle())
        }
    }
}

/// Questions people ask, each answered from the README or from what the app does. A question with no
/// source there does not belong here.
struct HelpView: View {
    let onFinish: () -> Void

    private static let questions: [(question: String, answer: String)] = [
        // README "Khi nào Ankey giữ nguyên từ tiếng Anh"; `Session.correction`; Settings → Chung → Từ Ankey đã học.
        ("Sao chữ tiếng Anh không bị đổi dấu?",
         "Ankey chỉ đổi khi kết quả là một âm tiết tiếng Việt có thật, và đã có sẵn hơn 200 từ tiếng Anh hay gặp như reset, test. Từ nào vẫn đổi nhầm thì xoá cả từ rồi gõ lại đúng phím đó: Ankey nhớ và để từ ấy nguyên chữ đã gõ. Xem và xoá các từ đã nhớ ở thẻ Chung."),
        // InputController cancelOperation; Settings → Chung → Esc huỷ từ đang gõ.
        ("Ankey đổi nhầm, lấy lại chữ đã gõ thế nào?",
         "Bấm Esc ngay: chữ trở về đúng phím đã gõ, tét thành test. Từ chưa ghép dấu thì Esc xoá hoặc chốt từ, chọn ở thẻ Chung → Esc huỷ từ đang gõ. Ankey giữ nguyên một từ mà bạn muốn đổi dấu (test thành tét) thì bấm Shift+Esc, bấm lần nữa để quay lại."),
        // Settings → Ứng dụng: footer and the help on the mode choice.
        ("Tắt, Gạch chân, Trực tiếp khác nhau thế nào?",
         "Chọn ở thẻ Ứng dụng → Thêm ứng dụng…. Tắt: Ankey không gõ ở đó. Gạch chân (mặc định): chữ gạch chân tới khi chốt. Trực tiếp: Cmd+A thấy đủ chữ, một số ứng dụng không hỗ trợ."),
        // `Trigger.all`; the Gửi góp ý… item in `AnkeyInputController.menu()`; FeedbackFlow key handling.
        ("Báo lỗi hoặc góp ý thế nào?",
         "Gõ ///feedback (góp ý) hay ///bug (báo lỗi) ở đầu từ, hoặc chọn Gửi góp ý… trong menu bộ gõ. Gõ nội dung rồi bấm Enter để gửi."),
        // FeedbackFlow key handling; FeedbackHUD note.
        ("///feedback gửi gì, ai nhận?",
         "Chỉ gửi khi bạn bấm Enter, Esc để bỏ. Gửi đoạn bạn gõ cùng macOS, chip, chế độ gõ, không có tên ứng dụng. Datadog còn nhận IP và user agent của bạn."),
        // Settings → Cập nhật footer; the update item in the input menu.
        ("Cập nhật thế nào?",
         "Ankey tự kiểm tra khi mở và mỗi ngày một lần. Có bản mới thì menu bộ gõ hiện Cập nhật lên…, Ankey chỉ cài khi bạn bấm. Muốn kiểm tra ngay thì dùng thẻ Cập nhật."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            PixelPage {
                PixelSection(title: "Mã gõ nhanh", footer: "Gõ mã ở đầu từ rồi làm theo hướng dẫn hiện ra.") {
                    TriggerRows()
                }
                PixelSection(title: "Hỏi đáp") {
                    ForEach(Self.questions, id: \.question) { item in
                        VStack(alignment: .leading, spacing: Pixel.unit) {
                            Text(item.question).foregroundStyle(Pixel.accent)
                            Text(item.answer).foregroundStyle(Pixel.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            HStack(spacing: 2 * Pixel.unit) {
                Button("Mở Cài đặt") { SettingsWindowController.shared.show() }
                    .buttonStyle(PixelButtonStyle())
                Spacer()
                Button("Đóng", action: onFinish)
                    .buttonStyle(PixelButtonStyle(primary: true))
            }
            .padding(.horizontal, 8 * Pixel.unit)
            .padding(.vertical, 5 * Pixel.unit)
        }
        .font(Pixel.font())
        .foregroundStyle(Pixel.text)
        .frame(width: 520, height: 440)
        .background(Pixel.bg)
    }
}

final class OnboardingWindowController: NSWindowController {
    static let shared = OnboardingWindowController()

    init() {
        let window = NSWindow()
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

    /// Starts from the top every time.
    func show(_ mode: GuideMode) {
        let close: () -> Void = { [weak self] in self?.close() }
        switch mode {
        case .firstRun: window?.contentViewController = NSHostingController(rootView: OnboardingView(onFinish: close))
        case .help: window?.contentViewController = NSHostingController(rootView: HelpView(onFinish: close))
        }
        window?.title = mode.title
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
    }
}
