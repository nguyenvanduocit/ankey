import Cocoa
import SwiftUI
import UniformTypeIdentifiers

/// A switch with a one-line explanation under its title.
struct OptionToggle: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
    }
}

/// Footer text of a grouped-Form section, left-aligned across the full section width.
struct SectionFooter: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GeneralTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Picker("Kiểu đặt dấu", selection: $model.value.toneStyle) {
                    Text("Kiểu mới (hoà, thuý)").tag(ToneStyle.modern)
                    Text("Kiểu cũ (hòa, thúy)").tag(ToneStyle.classic)
                }
            } header: {
                Text("Gõ tiếng Việt")
            } footer: {
                SectionFooter("Hai kiểu chỉ khác nhau ở oa, oe, uy khi không có phụ âm cuối.")
            }

            Section("Hành vi") {
                OptionToggle(
                    title: "Giữ nguyên chữ không phải tiếng Việt",
                    detail: "Gõ smart, text, hello ra đúng chữ đã gõ.",
                    isOn: $model.value.restoreRaw
                )
                OptionToggle(
                    title: "Esc huỷ từ đang gõ",
                    detail: "Từ đã ghép dấu: Esc trả lại chữ đã gõ. Từ khác: bật thì xoá từ, tắt thì chốt từ rồi gửi Esc cho ứng dụng.",
                    isOn: $model.value.escClears
                )
            }
        }
        .formStyle(.grouped)
    }
}

struct MacroRow: View {
    @Binding var macro: Macro
    let problem: Macro.Problem?
    let onDelete: () -> Void

    private var problemText: String? {
        switch problem {
        case .badShortcut: return "Chỉ dùng chữ a–z"
        case .emptyText: return "Thiếu nội dung"
        case .duplicate: return "Trùng"
        case nil: return nil
        }
    }

    var body: some View {
        HStack {
            TextField("Phím tắt", text: $macro.shortcut, prompt: Text("Phím tắt"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
            TextField("Nội dung", text: $macro.text, prompt: Text("Nội dung"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
            if let problemText {
                Text(problemText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Button(action: onDelete) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("Xoá")
        }
    }
}

struct MacrosTab: View {
    @ObservedObject var model: SettingsModel
    @State private var newWord = ""
    @State private var newEnglish = ""

    var body: some View {
        let problems = Macro.problems(in: model.value.macros)
        Form {
            Section {
                ForEach($model.value.macros) { $macro in
                    MacroRow(macro: $macro, problem: problems[macro.id]) {
                        model.value.macros.removeAll { $0.id == macro.id }
                    }
                }
                Button("Thêm phím tắt") {
                    model.value.macros.append(Macro(shortcut: "", text: ""))
                }
            } header: {
                Text("Mở rộng văn bản")
            } footer: {
                SectionFooter("Gõ phím tắt rồi bấm cách để thay bằng nội dung. Chữ hoa của phím tắt được áp vào kết quả.")
            }

            Section {
                OptionToggle(
                    title: "Cho phép từ viết tắt",
                    detail: "Những từ dưới đây được ghép dấu dù không phải âm tiết tiếng Việt. Cần bật mục giữ nguyên chữ ở tab Chung.",
                    isOn: $model.value.abbreviation
                )
                ForEach(model.value.shorthand, id: \.self) { word in
                    HStack {
                        Text(word)
                        Spacer()
                        Button {
                            model.value.shorthand.removeAll { $0 == word }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Xoá")
                    }
                }
                HStack {
                    TextField("Từ mới", text: $newWord, prompt: Text("Từ mới, ví dụ đt"))
                        .labelsHidden()
                        .onSubmit(addWord)
                    Button("Thêm", action: addWord)
                        .disabled(normalizedNewWord.isEmpty)
                }
            } header: {
                Text("Từ viết tắt")
            }
            .disabled(!model.value.restoreRaw)

            Section {
                ForEach(model.value.keepEnglish, id: \.self) { word in
                    HStack {
                        Text(word)
                        Spacer()
                        Button {
                            model.value.keepEnglish.removeAll { $0 == word }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Xoá")
                    }
                }
                HStack {
                    TextField("Từ mới", text: $newEnglish, prompt: Text("Từ mới, ví dụ test"))
                        .labelsHidden()
                        .onSubmit(addEnglish)
                    Button("Thêm", action: addEnglish)
                        .disabled(normalizedNewEnglish.isEmpty)
                }
            } header: {
                Text("Từ tiếng Anh giữ nguyên")
            } footer: {
                SectionFooter("Những từ này luôn ra đúng chữ đã gõ, ví dụ test không thành tét. Cần bật mục giữ nguyên chữ ở tab Chung.")
            }
            .disabled(!model.value.restoreRaw)
        }
        .formStyle(.grouped)
    }

    private var normalizedNewEnglish: String {
        newEnglish.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private func addEnglish() {
        let word = normalizedNewEnglish
        guard !word.isEmpty, !model.value.keepEnglish.contains(word) else { return }
        model.value.keepEnglish.append(word)
        newEnglish = ""
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
}

struct AppsTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                ForEach(model.value.excludedApps, id: \.self) { bundleID in
                    AppRow(bundleID: bundleID) {
                        model.value.excludedApps.removeAll { $0 == bundleID }
                    }
                }
                Button("Thêm ứng dụng…", action: addApp)
            } header: {
                Text("Ứng dụng tắt Ankey")
            } footer: {
                SectionFooter("Trong các ứng dụng này Ankey không ghép dấu, phím gõ đi thẳng vào ứng dụng.")
            }
        }
        .formStyle(.grouped)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier,
              !model.value.excludedApps.contains(bundleID)
        else { return }
        model.value.excludedApps.append(bundleID)
    }
}

struct AppRow: View {
    let bundleID: String
    let onDelete: () -> Void

    /// An app that is no longer installed shows its bundle ID as the name.
    private var info: (name: String, icon: NSImage?) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return (bundleID, nil)
        }
        let name = FileManager.default.displayName(atPath: url.path)
        return (name.replacingOccurrences(of: ".app", with: ""), NSWorkspace.shared.icon(forFile: url.path))
    }

    var body: some View {
        HStack {
            if let icon = info.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
            }
            VStack(alignment: .leading) {
                Text(info.name)
                Text(bundleID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("Xoá")
        }
    }
}
