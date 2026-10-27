import Cocoa
import SwiftUI

/// What Ankey learns and offers, and what it has learned so far: the switches for suggestions and learning, then
/// the lists the user can read and clear. The user's AI reads the same lists with `Ankey show learned`.
struct LearnedSections: View {
    @ObservedObject var model: SettingsModel
    @State private var learned = AdjustStore.shared.words
    @State private var phrases = PersonalPhrasesStore.shared.learned(limit: 40)
    @State private var habits = LanguageHabitsStore.shared.learned(limit: 40)

    var body: some View {
        // The spacing of `PixelPage`, so the sections sit where they would as direct children of the page.
        VStack(alignment: .leading, spacing: 5 * Pixel.unit) {
            PixelSection(
                title: "Học và gợi ý",
                footer: "Những gì Ankey học lưu trên máy này và không gửi đi. AI của bạn đọc được chúng bằng dòng lệnh."
            ) {
                PixelToggle(
                    title: "Gợi ý cụm từ",
                    detail: "Gõ vài từ của một cụm chỉ có một cách đi tiếp (xã hội chủ…): Ankey hiện phần còn lại, bấm Tab để nhận.",
                    isOn: $model.value.suggestions
                )
                PixelToggle(
                    title: "Học cụm từ bạn hay gõ",
                    detail: "Ankey nhớ các cụm bạn gõ lặp lại (tên dự án, thuật ngữ) để gợi ý lần sau. Lưu trên máy này, tối đa khoảng 2 MB, không gửi đi. Cụm lâu không dùng tự bị bỏ.",
                    isOn: $model.value.learnsPhrases
                )
                PixelToggle(
                    title: "Học khi nào bạn gõ tiếng Anh",
                    detail: "Ankey nhớ sau từ nào bạn thường gõ tiếng Anh hay tiếng Việt, rồi dùng khi một chữ có thể là cả hai (as, cos). Lưu trên máy này, tối đa khoảng 1 MB, không gửi đi. Esc, Shift+Esc và sửa chữ được tính nặng hơn.",
                    isOn: $model.value.learnsLanguage
                )
            }

            if model.value.learnsPhrases {
                PixelSection(
                    title: "Cụm Ankey đã học",
                    footer: phrases.isEmpty
                        ? "Chưa có cụm nào. Một cụm được gợi ý khi bạn gõ nó giống nhau từ ba lần."
                        : "Chỉ những cụm Ankey sẽ gợi ý. Bấm xoá để quên một cụm."
                ) {
                    ForEach(phrases, id: \.prefix) { row in
                        WordRow(word: "\(row.prefix) → \(row.word)  ×\(row.count)") {
                            PersonalPhrasesStore.shared.forget(prefix: row.prefix, word: row.word)
                            phrases = PersonalPhrasesStore.shared.learned(limit: 40)
                        }
                    }
                    Button("Xoá hết cụm đã học") {
                        PersonalPhrasesStore.shared.forgetAll()
                        phrases = []
                    }
                    .buttonStyle(PixelButtonStyle())
                }
            }

            if model.value.learnsLanguage {
                PixelSection(
                    title: "Thói quen ngôn ngữ",
                    footer: habits.isEmpty
                        ? "Chưa có thói quen nào. Cần ít nhất 8 lần gõ sau cùng một từ."
                        : "Sau những từ này bạn gần như luôn gõ cùng một thứ tiếng. Bấm xoá để quên."
                ) {
                    ForEach(habits, id: \.word) { row in
                        WordRow(word: "\(row.word) → \(row.language == .english ? "tiếng Anh" : "tiếng Việt")  ×\(row.samples)") {
                            LanguageHabitsStore.shared.forget(row.word)
                            habits = LanguageHabitsStore.shared.learned(limit: 40)
                        }
                    }
                    Button("Xoá hết thói quen") {
                        LanguageHabitsStore.shared.forgetAll()
                        habits = []
                    }
                    .buttonStyle(PixelButtonStyle())
                }
            }

            if !learned.isEmpty {
                PixelSection(
                    title: "Từ Ankey đã học",
                    footer: "Ankey đổi nhầm thì xoá cả từ rồi gõ lại đúng phím đó: từ ấy chuyển sang cách còn lại và được nhớ ở đây. Bấm xoá để quên."
                ) {
                    ForEach(learned.keys.sorted(), id: \.self) { word in
                        WordRow(word: "\(word)  \((learned[word] ?? 0) > 0 ? "giữ nguyên" : "ghép dấu")") {
                            AdjustStore.shared.set(word, to: 0)
                            learned = AdjustStore.shared.words
                        }
                    }
                }
            }
        }
        .onAppear(perform: refresh)
        // The window is built once and shown again, so the tab does not appear anew: read the stores whenever
        // the window comes forward, or a correction made since it first showed stays missing from the lists.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in refresh() }
    }

    private func refresh() {
        learned = AdjustStore.shared.words
        phrases = PersonalPhrasesStore.shared.learned(limit: 40)
        habits = LanguageHabitsStore.shared.learned(limit: 40)
    }
}
