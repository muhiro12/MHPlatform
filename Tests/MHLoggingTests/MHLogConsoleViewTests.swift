#if canImport(SwiftUI)
import Foundation
@testable import MHLogging
import Testing

struct MHLogConsoleViewTests {
    @Test
    @MainActor
    func makeExportFilename_uses_sanitized_iso8601_timestamp() {
        let view = MHLogConsoleView(store: .init())
        let filename = view.makeExportFilename(
            date: .init(timeIntervalSince1970: 1_767_225_600)
        )

        #expect(filename == "mhlogging-export-2026-01-01T00-00-00Z.jsonl")
    }
}
#endif
