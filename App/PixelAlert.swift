import Cocoa
import SwiftUI

/// The body of a pixel alert: app icon, title, message, and a row of buttons.
/// The first button is the default one and sits on the right.
struct PixelAlertView: View {
    let title: String
    let message: String
    let buttons: [String]
    let onChoose: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5 * Pixel.unit) {
            PixelAppIcon()
            Text(title)
                .font(Pixel.font(24))
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .foregroundStyle(Pixel.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 2 * Pixel.unit) {
                Spacer(minLength: 0)
                ForEach(Array(buttons.enumerated()).reversed(), id: \.offset) { index, label in
                    Button(label) { onChoose(index) }
                        .buttonStyle(PixelButtonStyle(primary: index == 0))
                        .keyboardShortcut(index == 0 ? .defaultAction : .cancelAction)
                }
            }
        }
        .padding(.horizontal, 8 * Pixel.unit)
        .padding(.top, 10 * Pixel.unit)
        .padding(.bottom, 8 * Pixel.unit)
        .font(Pixel.font())
        .foregroundStyle(Pixel.text)
        .frame(width: 190 * Pixel.unit)
        .background(Pixel.bg)
    }
}

/// Shows a pixel alert and blocks until a button is pressed. Returns that button's index.
@MainActor @discardableResult
func runPixelAlert(title: String, message: String, buttons: [String]) -> Int {
    var choice = 0
    let host = NSHostingController(rootView: PixelAlertView(title: title, message: message, buttons: buttons) { index in
        choice = index
        NSApp.stopModal()
    })
    let window = NSWindow(contentViewController: host)
    window.styleMask = [.titled, .fullSizeContentView]
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.appearance = NSAppearance(named: .darkAqua)
    window.backgroundColor = NSColor(Pixel.bg)
    window.isReleasedWhenClosed = false
    for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
        window.standardWindowButton(button)?.isHidden = true
    }
    window.center()
    NSApp.runModal(for: window)
    window.orderOut(nil)
    return choice
}
