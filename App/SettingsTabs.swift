import Cocoa
import SwiftUI
import UniformTypeIdentifiers

struct GeneralTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        PixelPage {
            PixelSection(
                title: "Gõ tiếng Việt",
                footer: "Hai kiểu chỉ khác nhau ở oa, oe, uy khi không có phụ âm cuối."
            ) {
                PixelChoice(
                    title: "Kiểu đặt dấu",
                    selection: $model.value.toneStyle,
                    options: [
                        ("Kiểu mới (hoà, thuý)", ToneStyle.modern),
                        ("Kiểu cũ (hòa, thúy)", ToneStyle.classic),
                    ]
                )
            }

            PixelSection(
                title: "Bảng mã",
                footer: "Bảng mã cũ chỉ hiện đúng khi font của văn bản là font cũ (.VnTime, VNI-Times). Đặt riêng cho từng ứng dụng ở thẻ Ứng dụng."
            ) {
                PixelChoice(
                    title: "Bảng mã mặc định",
                    selection: $model.value.encoding,
                    options: [
                        ("Unicode", OutputEncoding.unicode),
                        ("TCVN3", OutputEncoding.tcvn3),
                        ("VNI Windows", OutputEncoding.vniWindows),
                    ]
                )
            }

            PixelSection(title: "Hành vi") {
                PixelToggle(
                    title: "Giữ nguyên chữ không phải tiếng Việt",
                    detail: "Gõ smart, text, hello ra đúng chữ đã gõ.",
                    isOn: $model.value.restoreRaw
                )
                PixelToggle(
                    title: "Esc huỷ từ đang gõ",
                    detail: "Từ đã ghép dấu: Esc trả lại chữ đã gõ. Từ khác: bật thì xoá từ, tắt thì chốt từ rồi gửi Esc cho ứng dụng.",
                    isOn: $model.value.escClears
                )
            }
        }
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
        HStack(spacing: 2 * Pixel.unit) {
            TextField("Phím tắt", text: $macro.shortcut, prompt: Text("Phím tắt"))
                .labelsHidden()
                .pixelField()
                .frame(width: 110)
            Text("»").foregroundStyle(Pixel.accent)
            TextField("Nội dung", text: $macro.text, prompt: Text("Nội dung"))
                .labelsHidden()
                .pixelField()
            if let problemText {
                Text(problemText)
                    .font(Pixel.font(15))
                    .foregroundStyle(Pixel.danger)
            }
            PixelRemoveButton(action: onDelete)
        }
    }
}

struct WordRow: View {
    let word: String
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text(word)
            Spacer()
            PixelRemoveButton(action: onDelete)
        }
    }
}

struct MacrosTab: View {
    @ObservedObject var model: SettingsModel
    @State private var newWord = ""
    @State private var newEnglish = ""

    var body: some View {
        let problems = Macro.problems(in: model.value.macros)
        PixelPage {
            PixelSection(
                title: "Mở rộng văn bản",
                footer: "Gõ phím tắt rồi bấm cách để thay bằng nội dung. Chữ hoa của phím tắt được áp vào kết quả."
            ) {
                ForEach($model.value.macros) { $macro in
                    MacroRow(macro: $macro, problem: problems[macro.id]) {
                        model.value.macros.removeAll { $0.id == macro.id }
                    }
                }
                Button("Thêm phím tắt") {
                    model.value.macros.append(Macro(shortcut: "", text: ""))
                }
                .buttonStyle(PixelButtonStyle())
            }

            PixelSection(title: "Từ viết tắt") {
                PixelToggle(
                    title: "Cho phép từ viết tắt",
                    detail: "Những từ dưới đây được ghép dấu dù không phải âm tiết tiếng Việt. Cần bật mục giữ nguyên chữ ở tab Chung.",
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

            PixelSection(
                title: "Từ tiếng Anh giữ nguyên",
                footer: "Ankey đã có sẵn hơn 200 từ tiếng Anh thường gặp như reset, boot, test. Thêm từ của bạn ở đây, chúng luôn ra đúng chữ đã gõ. Cần bật mục giữ nguyên chữ ở tab Chung."
            ) {
                ForEach(model.value.keepEnglish, id: \.self) { word in
                    WordRow(word: word) {
                        model.value.keepEnglish.removeAll { $0 == word }
                    }
                }
                HStack(spacing: 2 * Pixel.unit) {
                    TextField("Từ mới", text: $newEnglish, prompt: Text("Từ mới, ví dụ test"))
                        .labelsHidden()
                        .pixelField()
                        .onSubmit(addEnglish)
                    Button("Thêm", action: addEnglish)
                        .buttonStyle(PixelButtonStyle())
                        .disabled(normalizedNewEnglish.isEmpty)
                }
            }
            .disabled(!model.value.restoreRaw)
        }
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
    @State private var showPicker = false

    var body: some View {
        PixelPage {
            ForEach($model.value.appRules, id: \.bundleID) { $rule in
                PixelSection {
                    AppRuleRows(rule: $rule) {
                        model.value.appRules.removeAll { $0.bundleID == rule.bundleID }
                    }
                }
            }
            PixelSection(
                footer: "Mỗi ứng dụng chọn tắt Ankey, gạch chân hoặc chèn trực tiếp. Ứng dụng không có trong danh sách dùng gạch chân."
            ) {
                Button("Thêm ứng dụng…") { showPicker = true }
                    .buttonStyle(PixelButtonStyle())
            }
        }
        .sheet(isPresented: $showPicker) {
            RunningAppPicker(
                added: Set(model.value.appRules.map(\.bundleID)),
                onPick: add,
                onBrowse: {
                    showPicker = false
                    DispatchQueue.main.async { browse() }
                },
                onClose: { showPicker = false }
            )
        }
    }

    private func add(_ bundleID: String) {
        guard !model.value.appRules.contains(where: { $0.bundleID == bundleID }) else { return }
        model.value.appRules.append(AppRule(bundleID: bundleID))
    }

    private func browse() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier
        else { return }
        add(bundleID)
    }
}

/// The apps that are running now, so the common case is one click. Browsing the disk is the fallback.
struct RunningAppPicker: View {
    let added: Set<String>
    let onPick: (String) -> Void
    let onBrowse: () -> Void
    let onClose: () -> Void

    private var apps: [(bundleID: String, name: String, icon: NSImage?)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let id = app.bundleIdentifier, !added.contains(id) else { return nil }
                return (id, app.localizedName ?? id, app.icon)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        let apps = apps
        VStack(alignment: .leading, spacing: 4 * Pixel.unit) {
            Text("ĐANG CHẠY")
                .font(Pixel.font(16))
                .foregroundStyle(Pixel.accent)
            ScrollView {
                VStack(spacing: 2 * Pixel.unit) {
                    ForEach(apps, id: \.bundleID) { app in
                        Button {
                            onPick(app.bundleID)
                            onClose()
                        } label: {
                            HStack(spacing: 3 * Pixel.unit) {
                                if let icon = app.icon {
                                    Image(nsImage: icon).resizable().frame(width: 28, height: 28)
                                }
                                VStack(alignment: .leading) {
                                    Text(app.name)
                                    Text(app.bundleID)
                                        .font(Pixel.font(15))
                                        .foregroundStyle(Pixel.muted)
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(PixelButtonStyle())
                    }
                    if apps.isEmpty {
                        Text("Không còn ứng dụng nào đang chạy để thêm.")
                            .foregroundStyle(Pixel.muted)
                            .padding(.vertical, 4 * Pixel.unit)
                    }
                }
            }
            HStack(spacing: 2 * Pixel.unit) {
                Button("Duyệt…", action: onBrowse)
                    .buttonStyle(PixelButtonStyle())
                Spacer()
                Button("Đóng", action: onClose)
                    .buttonStyle(PixelButtonStyle(primary: true))
            }
        }
        .padding(6 * Pixel.unit)
        .font(Pixel.font())
        .foregroundStyle(Pixel.text)
        .frame(width: 440, height: 380)
        .background(Pixel.bg)
    }
}

/// The rows of one app: who it is, whether Ankey runs, and how it behaves there.
struct AppRuleRows: View {
    @Binding var rule: AppRule
    let onDelete: () -> Void

    var body: some View {
        AppRow(bundleID: rule.bundleID, onDelete: onDelete)
        PixelChoice(
            title: "Gõ tiếng Việt",
            selection: $rule.mode,
            options: [
                ("Tắt", AppMode.off),
                ("Gạch chân", AppMode.marked),
                ("Trực tiếp", AppMode.direct),
            ],
            help: "Gạch chân: chữ đang gõ được gạch chân cho tới khi chốt. Trực tiếp: chữ không chờ gạch chân, nên Cmd+A và các phím tắt khác thấy đủ chữ. Một số ứng dụng không hỗ trợ."
        )
        PixelChoice(
            title: "Bảng mã",
            selection: $rule.encoding,
            options: [
                ("Mặc định", OutputEncoding?.none),
                ("Unicode", .unicode),
                ("TCVN3", .tcvn3),
                ("VNI Windows", .vniWindows),
            ]
        )
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
                    .font(Pixel.font(15))
                    .foregroundStyle(Pixel.muted)
            }
            Spacer()
            PixelRemoveButton(action: onDelete)
        }
    }
}
