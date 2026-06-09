#if canImport(SwiftUI)
import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension MHLogConsoleView {
    var activeQuery: MHLogQuery {
        .init(
            minimumLevel: visibleMinimumLevel,
            category: categoryFilter,
            searchText: searchText,
            limit: limit
        )
    }

    func prepareConsole() async {
        await refreshEvents()
    }

    func refreshEvents() async {
        let values: [MHLogEvent]
        if let logging {
            values = await logging.events(
                in: sessionScope,
                matching: activeQuery
            )
        } else {
            values = await store.events(matching: activeQuery)
        }

        await MainActor.run {
            events = values
            statusMessage = "Loaded \(values.count) event(s) from \(sessionScope.title.lowercased())"
        }
    }

    func copyJSONL() async {
        let jsonLines: String
        if let logging {
            jsonLines = await logging.exportJSONLines(
                in: sessionScope,
                matching: activeQuery
            )
        } else {
            jsonLines = await store.exportJSONLines(matching: activeQuery)
        }
        let copied = copyToClipboard(jsonLines)
        await MainActor.run {
            if copied {
                statusMessage = "Copied \(jsonLines.utf8.count) bytes as JSONL"
            } else {
                statusMessage = "Clipboard is not supported on this platform"
            }
        }
    }

    func exportJSONL() async {
        let jsonLines: String
        if let logging {
            jsonLines = await logging.exportJSONLines(
                in: sessionScope,
                matching: activeQuery
            )
        } else {
            jsonLines = await store.exportJSONLines(matching: activeQuery)
        }

        #if !os(watchOS)
        await MainActor.run {
            exportDocument = .init(jsonLines: jsonLines)
            exportFilename = makeExportFilename()
            isPresentingExporter = true
            statusMessage = "Prepared \(jsonLines.utf8.count) bytes for export"
        }
        #else
        _ = jsonLines
        await MainActor.run {
            statusMessage = "Export is not supported on this platform"
        }
        #endif
    }

    func clearLogs() async {
        if let logging {
            await logging.clear()
            await MainActor.run {
                sessionScope = .current
            }
        } else {
            await store.clear()
        }

        await refreshEvents()
        await MainActor.run {
            if logging == nil {
                statusMessage = "Cleared in-memory logs"
            } else {
                statusMessage = "Cleared current and previous session snapshots"
            }
        }
    }

    func copyToClipboard(_ value: String) -> Bool {
        #if os(iOS)
        UIPasteboard.general.string = value
        return true
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(value, forType: .string)
        #else
        _ = value
        return false
        #endif
    }

    package func makeExportFilename(date: Date = .init()) -> String {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: date)
            .replacingOccurrences(of: ":", with: "-")
        return "\(Constants.exportBaseName)-\(timestamp).jsonl"
    }
}
#endif
