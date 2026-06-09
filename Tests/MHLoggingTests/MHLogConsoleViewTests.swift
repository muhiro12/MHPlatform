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

    @Test
    @MainActor
    func eventAccessibilityText_includes_event_context() {
        let view = MHLogConsoleView(store: .init())
        let event = MHLogEvent(
            level: .error,
            subsystem: "com.example.app",
            category: "routing",
            message: "Failed to apply route",
            source: .init(
                file: "RouteService.swift",
                function: "apply()",
                line: 42
            ),
            timestamp: .init(timeIntervalSince1970: 1_767_225_600),
            metadata: ["route": "settings"]
        )

        #expect(view.eventAccessibilityLabel(event) == "ERROR log event")
        let accessibilityValue = [
            "2026-01-01T00:00:00Z",
            "com.example.app/routing",
            "Failed to apply route",
            "1 metadata items"
        ].joined(separator: ", ")
        #expect(view.eventAccessibilityValue(event) == accessibilityValue)
    }
}
#endif
