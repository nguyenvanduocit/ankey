import Cocoa
import SwiftUI

/// What the HUD shows. The capture states follow `Capture`; the rest are short notices.
enum HUDState: Equatable {
    case capture(ReportKind, text: String, phase: Capture.Phase)
    case sent
    /// The build has nowhere to send a report, so no capture starts.
    case unavailable
    /// A report went out after its capture ended and failed.
    case notSent(String)

    /// Notices go away by themselves. A capture stays until the user ends it.
    var visibleFor: Duration? {
        switch self {
        case .capture: return nil
        case .sent: return .seconds(2)
        case .unavailable: return .seconds(4)
        case .notSent: return .seconds(5)
        }
    }
}

@MainActor
final class HUDModel: ObservableObject {
    @Published var state = HUDState.sent
}

private extension ReportKind {
    var title: String {
        switch self {
        case .bug: return "Báo lỗi"
        case .feedback: return "Góp ý"
        }
    }
}

/// The report text as the user is typing it, a pixel panel that never touches the app's document.
struct FeedbackHUDView: View {
    @ObservedObject var model: HUDModel

    /// Long text shows its end, where the caret is.
    private static let shownCharacters = 260

    var body: some View {
        VStack(alignment: .leading, spacing: 3 * Pixel.unit) {
            switch model.state {
            case .capture(let kind, let text, let phase):
                capture(kind, text, phase)
            case .sent:
                Text("✓ Đã gửi. Cảm ơn bạn!").foregroundStyle(Pixel.accent)
            case .unavailable:
                Text("Góp ý chưa sẵn sàng").foregroundStyle(Pixel.gold)
                Text("Bản Ankey này chưa có nơi nhận góp ý.").foregroundStyle(Pixel.muted)
            case .notSent(let reason):
                Text("Chưa gửi được: \(reason)").foregroundStyle(Pixel.danger)
            }
        }
        .padding(.horizontal, 6 * Pixel.unit)
        .padding(.vertical, 5 * Pixel.unit)
        .frame(width: 270 * Pixel.unit, alignment: .leading)
        .pixelBox(fill: Pixel.bg)
        .font(Pixel.font())
        .foregroundStyle(Pixel.text)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func capture(_ kind: ReportKind, _ text: String, _ phase: Capture.Phase) -> some View {
        HStack {
            Text(Trigger.report(kind).code).foregroundStyle(Pixel.gold)
            Text(kind.title).foregroundStyle(Pixel.muted)
            Spacer(minLength: 0)
            Text(verbatim: "\(text.count)/\(Capture.limit)").foregroundStyle(Pixel.muted)
        }
        TimelineView(.periodic(from: .now, by: Self.blinkInterval)) { context in
            Self.entry(text, caretOn: phase != .sending && Self.caretVisible(at: context.date))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 3 * Pixel.unit)
        .padding(.vertical, 2 * Pixel.unit)
        .pixelBox(fill: Pixel.panelLo, raised: false)

        Text("Gửi kèm: macOS, chip, bảng mã, chế độ gõ. Datadog còn nhận IP và user agent của bạn.")
            .font(Pixel.font(15))
            .foregroundStyle(Pixel.muted)
            .lineLimit(1)
            .minimumScaleFactor(0.85)

        switch phase {
        case .typing:
            Text("Enter gửi · Esc huỷ").foregroundStyle(Pixel.muted)
        case .sending:
            HStack(spacing: 2 * Pixel.unit) {
                PixelSpinner()
                Text("Đang gửi…").foregroundStyle(Pixel.accent)
            }
        case .failed(let reason):
            Text("Chưa gửi được: \(reason)").foregroundStyle(Pixel.danger)
            Text("Enter thử lại · Esc huỷ").foregroundStyle(Pixel.muted)
        }
    }

    private static let blinkInterval = 0.5

    private static func caretVisible(at date: Date) -> Bool {
        Int(date.timeIntervalSinceReferenceDate / blinkInterval) % 2 == 0
    }

    /// The text with the caret at its end, or in front of the hint when the box is empty. An unlit
    /// caret keeps its width, so the line never reflows as it blinks.
    private static func entry(_ text: String, caretOn: Bool) -> Text {
        let caret = Text(verbatim: "▌").foregroundColor(caretOn ? Pixel.text : Color.clear)
        guard !text.isEmpty else {
            let hint = Text(verbatim: "Gõ nội dung rồi nhấn Enter…").foregroundColor(Pixel.muted)
            return Text("\(caret)\(hint)")
        }
        return Text("\(Text(verbatim: tail(text)))\(caret)")
    }

    private static func tail(_ text: String) -> String {
        text.count > shownCharacters ? "…" + text.suffix(shownCharacters) : text
    }
}

/// A floating panel at the bottom of the screen. It takes no focus and no clicks, so the app the
/// user is typing in stays active and every key still reaches the input method.
@MainActor
final class FeedbackHUD {
    static let shared = FeedbackHUD()

    private let model = HUDModel()
    private let panel: NSPanel
    private let host: NSHostingView<FeedbackHUDView>
    private var hideTask: Task<Void, Never>?

    private init() {
        host = NSHostingView(rootView: FeedbackHUDView(model: model))
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.contentView = host
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    }

    func show(_ state: HUDState) {
        hideTask?.cancel()
        hideTask = nil
        model.state = state
        host.layoutSubtreeIfNeeded()
        place(host.fittingSize)
        panel.orderFrontRegardless()
        guard let lifetime = state.visibleFor else { return }
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: lifetime)
            guard !Task.isCancelled else { return }
            self?.panel.orderOut(nil)
        }
    }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        panel.orderOut(nil)
    }

    private func place(_ size: NSSize) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let area = screen?.visibleFrame else { return }
        let origin = NSPoint(x: area.midX - size.width / 2, y: area.minY + area.height * 0.12)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
