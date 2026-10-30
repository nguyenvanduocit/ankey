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
        VStack(alignment: .leading, spacing: 5 * Pixel.unit) {
            PixelSection(
                title: "Học từ bạn",
                footer: "Lưu trên máy này, không gửi đi. AI của bạn đọc được bằng dòng lệnh."
            ) {
                PixelToggle(
                    title: "Gợi ý cụm từ",
                    detail: "Gõ vài từ của một cụm chỉ có một cách đi tiếp (xã hội chủ…): Ankey hiện phần còn lại, bấm Tab để nhận.",
                    isOn: $model.value.suggestions
                )
                if model.value.suggestions {
                    PixelToggle(
                        title: "Học cụm từ của bạn",
                        detail: "Nhớ các cụm bạn gõ lặp lại (tên dự án, thuật ngữ) để gợi ý lần sau. Cụm lâu không dùng tự bị bỏ. Tối đa 2 MB.",
                        isOn: $model.value.learnsPhrases
                    )
                    .padding(.leading, 6 * Pixel.unit)
                }
                PixelToggle(
                    title: "Học khi nào bạn gõ tiếng Anh",
                    detail: "Nhớ sau từ nào bạn hay đổi thứ tiếng (dùng → tiếng Anh), dùng khi một chữ có thể là cả hai (as, cos). Tối đa 1 MB.",
                    isOn: $model.value.learnsLanguage
                )
            }

            if model.value.suggestions && model.value.learnsPhrases {
                PixelSection(
                    title: "Cụm đã học",
                    footer: phrases.isEmpty
                        ? "Chưa có cụm nào. Một cụm được gợi ý khi bạn gõ nó giống nhau từ ba lần."
                        : "Những cụm Ankey sẽ gợi ý. Bấm xoá để quên một cụm."
                ) {
                    ForEach(phrases, id: \.prefix) { row in
                        WordRow(word: "\(row.prefix) → \(row.word)  ×\(row.count)") {
                            PersonalPhrasesStore.shared.forget(prefix: row.prefix, word: row.word)
                            phrases = PersonalPhrasesStore.shared.learned(limit: 40)
                        }
                    }
                    if !phrases.isEmpty {
                        Button("Xoá hết cụm đã học") {
                            PersonalPhrasesStore.shared.forgetAll()
                            phrases = []
                        }
                        .buttonStyle(PixelButtonStyle())
                    }
                }
            }

            if model.value.learnsLanguage {
                PixelSection(
                    title: "Thói quen ngôn ngữ",
                    footer: habits.isEmpty
                        ? "Chưa có thói quen nào. Cần ít nhất 8 lần đổi thứ tiếng sau cùng một từ."
                        : "Sau những từ này bạn gần như luôn đổi sang thứ tiếng kia. Bấm xoá để quên."
                ) {
                    ForEach(habits, id: \.word) { row in
                        WordRow(word: "\(row.word) → \(row.language == .english ? "tiếng Anh" : "tiếng Việt")  ×\(row.samples)") {
                            LanguageHabitsStore.shared.forget(row.word)
                            habits = LanguageHabitsStore.shared.learned(limit: 40)
                        }
                    }
                    if !habits.isEmpty {
                        Button("Xoá hết thói quen") {
                            LanguageHabitsStore.shared.forgetAll()
                            habits = []
                        }
                        .buttonStyle(PixelButtonStyle())
                    }
                }
            }

            if !learned.isEmpty {
                PixelSection(
                    title: "Từ đã điều chỉnh",
                    footer: "Ankey đổi nhầm thì xoá từ rồi gõ lại đúng phím: từ ấy chuyển sang cách còn lại và được nhớ ở đây. Bấm xoá để quên."
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
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in refresh() }
    }

    private func refresh() {
        learned = AdjustStore.shared.words
        phrases = PersonalPhrasesStore.shared.learned(limit: 40)
        habits = LanguageHabitsStore.shared.learned(limit: 40)
    }
}
