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
        Form {
            Section {
                LabeledContent("Phiên bản hiện tại", value: Updater.currentVersion.text)
                LabeledContent("Kiểm tra lần cuối", value: lastCheckText)
                statusRow
                Button("Kiểm tra ngay") { updater.check(userInitiated: true) }
                    .disabled(isBusy)
            } header: {
                Text("Cập nhật")
            } footer: {
                SectionFooter("Ankey tự kiểm tra mỗi ngày một lần và chỉ cài khi bạn bấm Cập nhật.")
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var statusRow: some View {
        switch updater.state {
        case .idle:
            EmptyView()
        case .checking:
            HStack {
                ProgressView().controlSize(.small)
                Text("Đang kiểm tra…")
            }
        case .upToDate:
            Text("Bạn đang dùng bản mới nhất.")
                .foregroundStyle(.secondary)
        case .available(let release):
            VStack(alignment: .leading, spacing: 6) {
                Text("Có bản mới \(release.version.text)")
                    .fontWeight(.semibold)
                if !release.notes.isEmpty {
                    Text(release.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Cập nhật lên \(release.version.text)") { updater.install() }
            }
        case .installing:
            HStack {
                ProgressView().controlSize(.small)
                Text("Đang cập nhật…")
            }
        case .failed(let message):
            Text(message)
                .foregroundStyle(.red)
        }
    }
}
