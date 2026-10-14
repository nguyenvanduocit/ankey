import SwiftUI

/// 16-bit look of the settings window: a 2pt layout grid, 1pt corner steps, a bevelled palette and the
/// VT323 font. 1pt steps are a quarter of the usual 8-bit pixel, so corners read nearly round.
enum Pixel {
    /// Layout grid for spacing and borders.
    static let unit: CGFloat = 2
    /// Drawing grid for corners and bevel lines: one point, two device pixels on Retina.
    static let pixel: CGFloat = 1

    static let bg = Color(hex: 0x14142B)
    static let panel = Color(hex: 0x23284A)
    static let panelHi = Color(hex: 0x3A4275)
    static let panelLo = Color(hex: 0x161A33)
    static let outline = Color(hex: 0x0A0B1A)
    static let accent = Color(hex: 0x4FD6C0)
    static let accentLo = Color(hex: 0x23907F)
    static let text = Color(hex: 0xF4F0E4)
    static let muted = Color(hex: 0x9AA2C8)
    static let danger = Color(hex: 0xFF6B7A)
    static let gold = Color(hex: 0xFFD166)

    static let fontName = "VT323-Regular"

    static func font(_ size: CGFloat = 18) -> Font { .custom(fontName, size: size) }

    /// The font file ships inside the app bundle. Registered once per process.
    static func registerFont() {
        guard let url = Bundle.main.url(forResource: "VT323-Regular", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// A rectangle whose corners step in one point at a time, following a rounded profile.
struct PixelRect: InsettableShape {
    var insetAmount: CGFloat = 0

    /// How far each row of a corner sits from the edge, outermost row first.
    private static let corner: [CGFloat] = [4, 2, 1, 1]

    func inset(by amount: CGFloat) -> PixelRect {
        PixelRect(insetAmount: insetAmount + amount)
    }

    /// One corner as offsets from the corner point, running from the top edge down to the side edge.
    private static let steps: [CGPoint] = {
        var points: [CGPoint] = []
        for (row, inset) in corner.enumerated() {
            points.append(CGPoint(x: inset, y: CGFloat(row)))
            points.append(CGPoint(x: inset, y: CGFloat(row + 1)))
        }
        points.append(CGPoint(x: 0, y: CGFloat(corner.count)))
        return points
    }()

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let steps = Self.steps
        var points: [CGPoint] = []
        points += steps.reversed().map { CGPoint(x: r.minX + $0.x, y: r.minY + $0.y) }
        points += steps.map { CGPoint(x: r.maxX - $0.x, y: r.minY + $0.y) }
        points += steps.reversed().map { CGPoint(x: r.maxX - $0.x, y: r.maxY - $0.y) }
        points += steps.map { CGPoint(x: r.minX + $0.x, y: r.maxY - $0.y) }
        var p = Path()
        p.addLines(points)
        p.closeSubpath()
        return p
    }
}

/// Outline, fill, and a one-point light edge on top and a dark edge below.
struct PixelBox: ViewModifier {
    var fill: Color = Pixel.panel
    var light: Color = Pixel.panelHi
    var dark: Color = Pixel.panelLo
    var raised = true

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    PixelRect().fill(Pixel.outline)
                    PixelRect().inset(by: Pixel.unit).fill(fill)
                }
            }
            .overlay(alignment: .top) {
                Rectangle().fill(raised ? light : dark)
                    .frame(height: Pixel.pixel)
                    .padding(.horizontal, 3 * Pixel.unit)
                    .padding(.top, Pixel.unit)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(raised ? dark : light)
                    .frame(height: Pixel.pixel)
                    .padding(.horizontal, 3 * Pixel.unit)
                    .padding(.bottom, Pixel.unit)
            }
    }
}

extension View {
    func pixelBox(
        fill: Color = Pixel.panel,
        light: Color = Pixel.panelHi,
        dark: Color = Pixel.panelLo,
        raised: Bool = true
    ) -> some View {
        modifier(PixelBox(fill: fill, light: light, dark: dark, raised: raised))
    }

    /// A text field sunk into the panel.
    func pixelField() -> some View {
        textFieldStyle(.plain)
            .padding(.horizontal, 3 * Pixel.unit)
            .padding(.vertical, 2 * Pixel.unit)
            .pixelBox(fill: Pixel.panelLo, raised: false)
            .tint(Pixel.accent)
    }
}

struct PixelButtonStyle: ButtonStyle {
    var primary = false
    var minWidth: CGFloat = 40 * Pixel.unit
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed
        configuration.label
            .frame(minWidth: minWidth)
            .foregroundStyle(primary ? Pixel.outline : Pixel.text)
            .padding(.horizontal, 4 * Pixel.unit)
            .padding(.vertical, 2 * Pixel.unit)
            .pixelBox(
                fill: primary ? Pixel.accent : Pixel.panelHi,
                light: primary ? Color.white.opacity(0.55) : Pixel.muted.opacity(0.6),
                dark: primary ? Pixel.accentLo : Pixel.panel,
                raised: !down
            )
            .offset(y: down ? Pixel.unit : 0)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.easeOut(duration: 0.06), value: down)
    }
}

/// The small delete button at the end of a row.
struct PixelRemoveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("×").foregroundStyle(Pixel.danger)
        }
        .buttonStyle(PixelButtonStyle(minWidth: 0))
        .help("Xoá")
    }
}

/// A switch with a title and an optional one-line explanation. The whole row is the hit target.
struct PixelToggle: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 3 * Pixel.unit) {
                VStack(alignment: .leading, spacing: Pixel.unit) {
                    Text(title)
                    if let detail {
                        Text(detail)
                            .font(Pixel.font(15))
                            .foregroundStyle(Pixel.muted)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                PixelSwitch(isOn: isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

private struct PixelSwitch: View {
    let isOn: Bool
    private let knob = 5 * Pixel.unit

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Color.clear
            Rectangle()
                .fill(isOn ? Pixel.text : Pixel.muted)
                .frame(width: knob, height: knob)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(isOn ? Pixel.accentLo : Pixel.panelHi).frame(height: Pixel.unit)
                }
        }
        .padding(2 * Pixel.unit)
        .frame(width: 20 * Pixel.unit, height: 9 * Pixel.unit)
        .pixelBox(fill: isOn ? Pixel.accent : Pixel.panelLo, light: Pixel.panelLo, dark: Pixel.outline, raised: false)
        .animation(.easeOut(duration: 0.12), value: isOn)
    }
}

/// A row of mutually exclusive choices that replaces a menu Picker.
struct PixelChoice<Value: Hashable>: View {
    var title: String?
    @Binding var selection: Value
    let options: [(label: String, value: Value)]
    var help: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2 * Pixel.unit) {
            if let title { Text(title) }
            HStack(spacing: 2 * Pixel.unit) {
                ForEach(options.indices, id: \.self) { index in
                    let option = options[index]
                    Button { selection = option.value } label: {
                        Text(option.label).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelButtonStyle(primary: selection == option.value))
                }
            }
        }
        .help(help ?? "")
    }
}

/// A titled panel holding rows, with an optional note underneath.
struct PixelSection<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder let content: Content
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 2 * Pixel.unit) {
            if let title {
                Text(title.uppercased())
                    .font(Pixel.font(16))
                    .foregroundStyle(Pixel.accent)
                    .padding(.leading, Pixel.unit)
            }
            VStack(alignment: .leading, spacing: 4 * Pixel.unit) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4 * Pixel.unit)
            .pixelBox()
            if let footer {
                Text(footer)
                    .font(Pixel.font(15))
                    .foregroundStyle(Pixel.muted)
                    .padding(.horizontal, Pixel.unit)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(isEnabled ? 1 : 0.5)
    }
}

/// Scrolling page of sections, shared by every tab.
struct PixelPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5 * Pixel.unit) {
                content
            }
            .padding(.horizontal, 8 * Pixel.unit)
            .padding(.vertical, 6 * Pixel.unit)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Three squares that light up in turn while something runs.
struct PixelSpinner: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate / 0.2) % 3
            HStack(spacing: Pixel.unit) {
                ForEach(0..<3, id: \.self) { index in
                    Rectangle()
                        .fill(index == step ? Pixel.accent : Pixel.panelHi)
                        .frame(width: 3 * Pixel.unit, height: 3 * Pixel.unit)
                }
            }
        }
    }
}

/// The app icon redrawn on the pixel grid: a teal tile with a stepped "V".
struct PixelAppIcon: View {
    private static let glyph = [
        "XX.....XX",
        "XX.....XX",
        ".XX...XX.",
        ".XX...XX.",
        "..XX.XX..",
        "..XX.XX..",
        "...XXX...",
        "...XXX...",
        "....X....",
    ]
    private let cell = 2 * Pixel.unit

    var body: some View {
        Canvas { context, size in
            let rows = Self.glyph
            let width = CGFloat(rows[0].count) * cell
            let height = CGFloat(rows.count) * cell
            let origin = CGPoint(x: (size.width - width) / 2, y: (size.height - height) / 2)
            for (y, row) in rows.enumerated() {
                for (x, mark) in row.enumerated() where mark == "X" {
                    let rect = CGRect(x: origin.x + CGFloat(x) * cell, y: origin.y + CGFloat(y) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(Pixel.outline))
                }
            }
        }
        .frame(width: 28 * Pixel.unit, height: 28 * Pixel.unit)
        .pixelBox(fill: Pixel.accent, light: Color.white.opacity(0.55), dark: Pixel.accentLo)
    }
}
