import Cocoa
import SwiftUI

/// How the user's AI reaches Ankey, the diary switch, and what the AI changed with the command line.
struct AITab: View {
    @ObservedObject var model: SettingsModel
    @State private var changes: [Change] = []
    @State private var copied = false

    private var executable: String { Bundle.main.executablePath ?? "Ankey" }

    /// What the user pastes into their AI. The guide is served by the installed app, so it matches this version.
    private var prompt: String {
        "Chạy \"\(executable)\" guide rồi làm theo hướng dẫn đó để đọc cài đặt bộ gõ Ankey của tôi và giúp tôi chỉnh nó."
    }

    var body: some View {
        PixelPage {
            PixelSection(
                title: "Kết nối AI",
                footer: "Dán lời nhắc vào AI chạy được lệnh shell (Claude Code, Codex, Cursor…). AI chạy Ankey guide để biết các lệnh, đọc cài đặt, những gì Ankey đã học và số đếm, rồi đề nghị thay đổi cho bạn duyệt. Mọi thứ nằm trên máy này. AI chỉ được tắt, không bao giờ được bật các mục lưu chữ bạn gõ."
            ) {
                Button(copied ? "Đã sao chép" : "Sao chép lời nhắc", action: copyPrompt)
                    .buttonStyle(PixelButtonStyle(primary: true))
            }

            LearnedSections(model: model)

            PixelSection(
                title: "Nhật ký",
                footer: "Tắt mặc định vì nó lưu chữ bạn gõ và tên ứng dụng: phím đã gõ và chữ Ankey đã hiện cho mỗi từ bạn lấy lại (Esc, Shift+Esc, xoá rồi gõ lại), cùng số từ gõ trong mỗi ứng dụng. Chỉ nằm trong một file chỉ bạn đọc được trên máy này, tối đa 2.000 mục trong 30 ngày, không gửi đi và không nằm trong thống kê. Tắt là xoá hết."
            ) {
                PixelToggle(
                    title: "Ghi nhật ký những từ bạn lấy lại",
                    detail: "Giúp AI thấy ứng dụng nào Ankey hay gõ sai.",
                    isOn: $model.value.keepsDiary
                )
                if model.value.keepsDiary {
                    Button("Xoá nhật ký") { DiaryStore.shared.forgetAll() }
                        .buttonStyle(PixelButtonStyle())
                }
            }

            PixelSection(
                title: "AI đã chỉnh",
                footer: "Những thay đổi AI làm bằng dòng lệnh. Hoàn tác trả lại giá trị cũ của thay đổi mới nhất làm được."
            ) {
                if changes.isEmpty {
                    Text("Chưa có thay đổi nào.").foregroundStyle(Pixel.muted)
                } else {
                    ForEach(Array(changes.prefix(5).enumerated()), id: \.offset) { _, change in
                        VStack(alignment: .leading, spacing: Pixel.unit) {
                            Text(change.summary)
                            Text(ago(change.time)).font(Pixel.font(15)).foregroundStyle(Pixel.muted)
                        }
                    }
                    if changes.contains(where: { $0.undo != nil }) {
                        Button("Hoàn tác", action: undo).buttonStyle(PixelButtonStyle())
                    }
                }
            }
        }
        .onAppear(perform: refresh)
        // The window is built once and shown again, and the command line writes the log from another process.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in refresh() }
        .onChange(of: model.value.keepsDiary) { isOn in
            if !isOn { DiaryStore.shared.forgetAll() }
        }
    }

    private func refresh() {
        changes = AIFiles.readChangeLog().changes.reversed()
    }

    private func copyPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        copied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            copied = false
        }
    }

    /// Takes the newest change that can be undone, with the same rules as `Ankey undo`.
    private func undo() {
        let settings = model.value
        guard let next = try? AIFiles.updateChangeLog({ (log: inout ChangeLog) throws -> Settings in
            guard let popped = log.popUndo() else { throw AIError.failed("Nothing to undo.") }
            return try popped.edit.applying(to: settings).settings
        }) else { return }
        model.value = next
        refresh()
    }

    private func ago(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "vi")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
