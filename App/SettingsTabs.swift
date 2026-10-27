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
            help: "Gạch chân: chữ đang gõ được gạch chân cho tới khi chốt. Trực tiếp: chữ không chờ gạch chân, nên Cmd+A và các phím tắt khác thấy đủ chữ, và Backspace xoá từng chữ đang hiện. Một số ứng dụng không hỗ trợ."
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
