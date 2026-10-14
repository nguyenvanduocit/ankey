import SwiftUI

struct UpdatesTab: View {
    @ObservedObject var updater = Updater.shared

    private var lastCheckText: String {
        updater.lastCheck?.formatted(date: .abbreviated, time: .shortened) ?? "Chưa lần nào"
    }

    private var isBusy: Bool {
        switch updater.state {
        case .checking, .installing: return true
        default: return false
        }
    }

    var body: some View {
        PixelPage {
            PixelSection(
                title: "Cập nhật",
                footer: "Ankey tự kiểm tra mỗi ngày một lần và chỉ cài khi bạn bấm Cập nhật."
            ) {
                row("Phiên bản hiện tại", Updater.currentVersion.text)
                row("Kiểm tra lần cuối", lastCheckText)
                statusRow
                Button("Kiểm tra ngay") { updater.check(userInitiated: true) }
                    .buttonStyle(PixelButtonStyle())
                    .disabled(isBusy)
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(Pixel.muted)
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch updater.state {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 3 * Pixel.unit) {
                PixelSpinner()
                Text("Đang kiểm tra…")
            }
        case .upToDate:
            Text("Bạn đang dùng bản mới nhất.")
                .foregroundStyle(Pixel.muted)
        case .available(let release):
            VStack(alignment: .leading, spacing: 3 * Pixel.unit) {
                Text("Có bản mới \(release.version.text)")
                    .foregroundStyle(Pixel.gold)
                if !release.notes.isEmpty {
                    Text(release.notes)
                        .font(Pixel.font(15))
                        .foregroundStyle(Pixel.muted)
                }
                Button("Cập nhật lên \(release.version.text)") { updater.install() }
                    .buttonStyle(PixelButtonStyle(primary: true))
            }
        case .installing:
            HStack(spacing: 3 * Pixel.unit) {
                PixelSpinner()
                Text("Đang cập nhật…")
            }
        case .failed(let message):
            Text(message)
                .foregroundStyle(Pixel.danger)
        }
    }
}
