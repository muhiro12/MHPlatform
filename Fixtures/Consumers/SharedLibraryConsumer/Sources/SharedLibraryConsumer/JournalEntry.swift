import SwiftData

@Model
final class JournalEntry {
    var title = ""

    init(title: String) {
        self.title = title
    }
}
