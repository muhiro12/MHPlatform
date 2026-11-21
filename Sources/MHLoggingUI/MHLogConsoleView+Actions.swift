#if canImport(SwiftUI)
import Foundation
import MHLogging

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension MHLogConsoleView {
    var activeQuery: MHLogQuery {
        .init(
            minimumLevel: selectedVisibleMinimumLevel,
            category: currentCategoryFilter,
            searchText: currentSearchText,
            limit: eventLimit
        )
    }

    func prepareConsole() async {
        await refreshEvents()
    }

    func refreshEvents() async {
        let values: [MHLogEvent]
        if let logging {
            values = await logging.events(
                in: selectedSessionScope,
                matching: activeQuery
            )
        } else {
            values = await store.events(matching: activeQuery)
        }

        await MainActor.run {
            visibleEvents = values
            consoleStatusMessage = "Loaded \(values.count) event(s) from \(selectedSessionScope.title.lowercased())"
        }
    }

    #if os(iOS) || os(macOS)
    func copyJSONL() async {
        let jsonLines: String
        if let logging {
            jsonLines = await logging.exportJSONLines(
                in: selectedSessionScope,
                matching: activeQuery
            )
        } else {
            jsonLines = await store.exportJSONLines(matching: activeQuery)
        }
        let copied = copyToClipboard(jsonLines)
        await MainActor.run {
            if copied {
                consoleStatusMessage = "Copied \(jsonLines.utf8.count) bytes as JSONL"
            } else {
                consoleStatusMessage = "Could not copy logs to the clipboard"
            }
        }
    }

    func copyToClipboard(_ value: String) -> Bool {
        #if os(iOS)
        UIPasteboard.general.string = value
        return true
        #else
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(value, forType: .string)
        #endif
    }
    #endif

    #if !os(watchOS)
    func exportJSONL() async {
        let jsonLines: String
        if let logging {
            jsonLines = await logging.exportJSONLines(
                in: selectedSessionScope,
                matching: activeQuery
            )
        } else {
            jsonLines = await store.exportJSONLines(matching: activeQuery)
        }

        await MainActor.run {
            preparedExportDocument = .init(jsonLines: jsonLines)
            preparedExportFilename = makeExportFilename()
            isExporterPresented = true
            consoleStatusMessage = "Prepared \(jsonLines.utf8.count) bytes for export"
        }
    }
    #endif

    func clearLogs() async {
        if let logging {
            await logging.clear()
            await MainActor.run {
                selectedSessionScope = .current
            }
        } else {
            await store.clear()
        }

        await refreshEvents()
        await MainActor.run {
            if logging == nil {
                consoleStatusMessage = "Cleared in-memory logs"
            } else {
                consoleStatusMessage = "Cleared current and previous session snapshots"
            }
        }
    }

    package func makeExportFilename() -> String {
        makeExportFilename(date: .init())
    }

    package func makeExportFilename(date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: date)
            .replacingOccurrences(of: ":", with: "-")
        return "\(Constants.exportBaseName)-\(timestamp).jsonl"
    }
}
#endif
