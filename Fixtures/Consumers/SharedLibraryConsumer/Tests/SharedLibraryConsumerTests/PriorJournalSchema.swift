import SwiftData

enum PriorJournalSchema {
    @Model
    final class Entry {
        var title = ""
        var oldField: String?

        init(oldField: String?) {
            self.oldField = oldField
        }
    }
}
