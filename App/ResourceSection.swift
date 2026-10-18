import SwiftUI

/// Memory and CPU of Ankey itself, read once a second while the tab is open. Nothing is saved or sent.
struct ResourceSection: View {
    private static let kept = 600

    @State private var latest: ResourceSample?
    @State private var cpu = 0.0
    @State private var memoryHistory: [Double] = []
    @State private var cpuHistory: [Double] = []
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        PixelSection(
            title: "Tài nguyên",
            footer: "Số đo của chính Ankey, cập nhật mỗi giây khi tab này mở. CPU tính theo một lõi, nên nhiều luồng có thể vượt 100%. Không lưu và không gửi đi."
        ) {
            if let latest {
                row("Bộ nhớ", ResourceUsage.size(latest.footprintBytes), note: "đỉnh \(ResourceUsage.size(latest.peakFootprintBytes))")
                PixelBars(values: memoryHistory, minimumCeiling: 1)
                row("CPU", ResourceUsage.percent(cpu))
                PixelBars(values: cpuHistory, minimumCeiling: 5)
                row("Luồng", "\(latest.threads)")
                row("Đã chạy", ResourceUsage.duration(latest.uptime))
                if let phrases = PhraseIndex.bundled {
                    row("Chỉ mục gợi ý", ResourceUsage.size(UInt64(phrases.byteCount)))
                }
            }
        }
        .onAppear(perform: read)
        .onReceive(tick) { _ in read() }
    }

    private func read() {
        guard let now = ProcessUsage.sample() else { return }
        if let earlier = latest {
            cpu = ResourceUsage.cpuPercent(from: earlier, to: now)
            cpuHistory = Array((cpuHistory + [cpu]).suffix(Self.kept))
        }
        memoryHistory = Array((memoryHistory + [Double(now.footprintBytes)]).suffix(Self.kept))
        latest = now
    }

    private func row(_ title: String, _ value: String, note: String? = nil) -> some View {
        HStack {
            Text(title)
            if let note { Text("(\(note))").foregroundStyle(Pixel.muted) }
            Spacer()
            Text(value).foregroundStyle(Pixel.muted)
        }
    }
}

/// The latest readings as pixel columns across the full width, newest on the right, as tall as their share of the ceiling. The ceiling sits above the highest
/// visible reading, so a steady value stays below the top and growth shows as a column that reaches it.
private struct PixelBars: View {
    let values: [Double]
    let minimumCeiling: Double
    private let height = 14 * Pixel.unit

    var body: some View {
        GeometryReader { proxy in
            let columns = max(1, Int((proxy.size.width + Pixel.pixel) / (Pixel.unit + Pixel.pixel)))
            let visible = Array(values.suffix(columns))
            let ceiling = max(minimumCeiling, (visible.max() ?? minimumCeiling) * 1.25)
            HStack(alignment: .bottom, spacing: Pixel.pixel) {
                ForEach(visible.indices, id: \.self) { index in
                    Rectangle()
                        .fill(Pixel.accent)
                        .frame(width: Pixel.unit, height: max(Pixel.unit, height * visible[index] / ceiling))
                }
            }
            .frame(width: proxy.size.width, height: height, alignment: .bottomLeading)
        }
        .frame(height: height)
    }
}
