import Foundation

/// The line the user hands to their AI so it finds the guide the installed app serves. The Settings tab copies it
/// and `///ai` types it. It is one line, so a chat box that sends on Return does not send it half typed.
enum AIPrompt {
    static func text(executable: String) -> String {
        "Chạy \"\(executable)\" guide rồi làm theo hướng dẫn đó để đọc cài đặt bộ gõ Ankey của tôi và giúp tôi chỉnh nó."
    }
}
