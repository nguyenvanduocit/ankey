import Cocoa
import SwiftUI

/// The statistics switches and the exact data they keep and send.
struct StatsTab: View {
    @ObservedObject var model: SettingsModel

    /// The request body as it would go to Datadog. Datadog also sees this machine's IP address and user agent.
    /// It goes to the clipboard and is never drawn in the window, because its size grows with the log.
    private func payloadJSON() -> String {
        let installID = model.value.shareStats ? StatsStore.installID() : nil
        let events = StatsPayload.forThisMac(settings: model.value, log: StatsStore.load()).events(installID: installID)
        return String(data: LogIntake.body(events, pretty: true), encoding: .utf8) ?? "[]"
    }

    var body: some View {
        PixelPage {
            ResourceSection()

            PixelSection(
                title: "Thống kê",
                footer: "Ankey chỉ đếm số lần. Không lưu chữ bạn gõ, phím bấm hay tên ứng dụng. Tắt đi là xoá hết số đã đếm."
            ) {
                PixelToggle(
                    title: "Ghi thống kê trên máy",
                    detail: "Đếm số từ được đổi dấu, số từ giữ nguyên, số lần Esc trả lại chữ đã gõ, số lần Shift+Esc đảo cách đọc, số lần Ankey học lại một từ từ lời sửa, số lần thói quen ngôn ngữ của bạn đổi cách hiển thị một chữ, số lần gợi ý cụm từ hiện ra, được nhận bằng Tab hay bị tắt bằng Esc, Backspace (tách gợi ý từ danh sách chung và gợi ý học từ bạn) và số lần chèn trực tiếp bị lệch. Chỉ lưu trên máy này.",
                    isOn: $model.value.collectStats
                )
            }

            if DatadogConfig.isConfigured {
                PixelSection(
                    title: "Chia sẻ",
                    footer: "Mỗi ngày Ankey gửi số liệu của những ngày đã qua tới Datadog, tối đa một lần. Datadog nhận số liệu thống kê (bấm Sao chép để xem đúng nội dung), một ID ngẫu nhiên của bản cài này, địa chỉ IP và user agent của máy bạn (mọi kết nối mạng đều gửi hai thứ sau). Tắt đi là bỏ ID, số liệu đã gửi nằm ở Datadog tới khi hết hạn lưu."
                ) {
                    PixelToggle(
                        title: "Gửi thống kê tới Datadog",
                        detail: "Giúp biết bộ gõ đúng hay sai ở đâu. Cần bật ghi thống kê.",
                        isOn: $model.value.shareStats
                    )
                    .disabled(!model.value.collectStats)
                }
            }

            if model.value.collectStats {
                PixelSection(
                    title: "Dữ liệu",
                    footer: model.value.shareStats
                        ? "Sao chép để xem đúng nội dung sẽ gửi. Máy giữ 30 ngày gần nhất."
                        : "Sao chép để xem toàn bộ số liệu trên máy. Máy giữ 30 ngày gần nhất."
                ) {
                    HStack(spacing: 2 * Pixel.unit) {
                        Button("Sao chép") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(payloadJSON(), forType: .string)
                        }
                        .buttonStyle(PixelButtonStyle())
                        Button("Xoá số liệu") { StatsStore.clear() }
                            .buttonStyle(PixelButtonStyle())
                    }
                }
            }
        }
        .onChange(of: model.value.collectStats) { isOn in
            guard !isOn else { return }
            model.value.shareStats = false
            StatsStore.clear()
        }
        .onChange(of: model.value.shareStats) { isOn in
            if !isOn { StatsStore.forgetSharing() }
        }
    }
}
