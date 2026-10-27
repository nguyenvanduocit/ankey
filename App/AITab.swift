import Cocoa
import SwiftUI

struct AITab: View {
    @ObservedObject var model: SettingsModel
    @State private var changes: [Change] = []
    @State private var copied = false
    @State private var newWord = ""

    private var executable: String { Bundle.main.executablePath ?? "Ankey" }
    private var prompt: String { AIPrompt.text(executable: executable) }

    var body: some View {
        PixelPage {
            PixelSection(
                title: "Kết nối AI",
                footer: "Dán lời nhắc vào AI (Claude Code, Codex, Cursor…) hoặc gõ ///ai để Ankey điền tại chỗ. AI chỉ được tắt, không bao giờ được bật lưu chữ."
            ) {
                Button(copied ? "Đã sao chép" : "Sao chép lời nhắc", action: copyPrompt)
                    .buttonStyle(PixelButtonStyle(primary: true))
            }

            LearnedSections(model: model)

            PixelSection(
                title: "Từ viết tắt",
                footer: !model.value.restoreRaw ? "Cần bật \u{201c}Giữ nguyên chữ không phải tiếng Việt\u{201d} ở tab Chung." : nil
            ) {
                PixelToggle(
                    title: "Cho phép từ viết tắt",
                    detail: "Những từ dưới đây được ghép dấu dù không phải âm tiết tiếng Việt.",
                    isOn: $model.value.abbreviation
                )
                ForEach(model.value.shorthand, id: \.self) { word in
                    WordRow(word: word) {
                        model.value.shorthand.removeAll { $0 == word }
                    }
                }
                HStack(spacing: 2 * Pixel.unit) {
                    TextField("Từ mới", text: $newWord, prompt: Text("Từ mới, ví dụ đt"))
                        .labelsHidden()
                        .pixelField()
                        .onSubmit(addWord)
                    Button("Thêm", action: addWord)
                        .buttonStyle(PixelButtonStyle())
                        .disabled(normalizedNewWord.isEmpty)
                }
            }
            .disabled(!model.value.restoreRaw)

            if !model.value.customMap.isEmpty {
                PixelSection(
                    title: "Bộ gõ tắt",
                    footer: "Gõ chuỗi này, Ankey trả về từ đặt sẵn thay vì qua Telex. Thêm bằng: ankey custom-map add <chuỗi> <từ>."
                ) {
                    ForEach(model.value.customMap.sorted { $0.key < $1.key }, id: \.key) { pair in
                        WordRow(word: "\(pair.key) → \(pair.value)") {
                            model.value.customMap.removeValue(forKey: pair.key)
                        }
                    }
                }
            }

            PixelSection(
                title: "Nhật ký",
                footer: "Lưu phím gõ và chữ Ankey hiện cho mỗi từ lấy lại, cùng số từ theo ứng dụng. Chỉ trên máy này, tối đa 2.000 mục. Tắt là xoá hết."
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
                footer: "Những thay đổi AI làm bằng dòng lệnh. Hoàn tác trả lại giá trị cũ của thay đổi mới nhất."
            ) {
                if changes.isEmpty {
                    Text("Chưa có thay đổi nào.").foregroundStyle(Pixel.muted)
                } else {
                    ForEach(Array(changes.enumerated()), id: \.offset) { _, change in
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
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in refresh() }
        .onChange(of: model.value.keepsDiary) { isOn in
            if !isOn { DiaryStore.shared.forgetAll() }
        }
    }

    private var normalizedNewWord: String {
        newWord.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private func addWord() {
        let word = normalizedNewWord
        guard !word.isEmpty, !model.value.shorthand.contains(word) else { return }
        model.value.shorthand.append(word)
        newWord = ""
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
