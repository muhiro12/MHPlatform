import MHPlatform
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct LoggingDemoView: View {
    private enum Constants {
        static let subsystem = "MHPlatformExample"
        static let category = "LoggingDemo"
        static let previewLineLimit = 8
        static let exportLimit = 100
        static let batchCount = 5
    }

    @State private var logging = MHLoggingBootstrap(
        subsystem: Constants.subsystem
    )
    @State private var previewText = "No persisted JSONL yet."
    @State private var status = "Emit samples or open the console for filtering."

    var body: some View {
        NavigationStack {
            List {
                modeSection()
                emitSection()
                actionsSection()
                previewSection()
                consoleSection()
                statusSection()
            }
            .navigationTitle("MHLogging")
            .task {
                await logging.waitForInitialLoad()
                await refreshPreview()
            }
        }
    }

    private func modeSection() -> some View {
        @Bindable var logging = logging

        return Section("Mode") {
            Toggle("Debug Mode", isOn: $logging.isDebugMode)
        }
    }

    private func emitSection() -> some View {
        Section("Emit Sample Events") {
            Button("Emit Info") {
                Task {
                    await emitInfoEvent()
                }
            }
            Button("Emit Warning") {
                Task {
                    await emitWarningEvent()
                }
            }
            Button("Emit Error") {
                Task {
                    await emitErrorEvent()
                }
            }
            Button("Emit Batch") {
                Task {
                    await emitBatchEvents()
                }
            }
        }
    }

    private func actionsSection() -> some View {
        Section("Actions") {
            Button("Refresh JSONL Preview") {
                Task {
                    await refreshPreview()
                }
            }
            Button("Export Latest 100 as JSONL to Clipboard") {
                Task {
                    await exportLatestEvents()
                }
            }
            Button("Clear Store + JSONL") {
                Task {
                    await clearAllLogs()
                }
            }
        }
    }

    private func previewSection() -> some View {
        Section("Persisted JSONL Preview") {
            Text(previewText)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }

    private func consoleSection() -> some View {
        Section("Console") {
            NavigationLink("Open MHLogConsoleView") {
                MHLogConsoleView(store: logging.store)
            }
            Text("Use level/category/search filters in the console.")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }

    private func statusSection() -> some View {
        Section("Status") {
            Text(status)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }

    private func refreshPreview() async {
        let text = await logging.persistedJSONLines()
        let lines = text.split { character in
            character.isNewline
        }
        let visibleLines = lines.suffix(Constants.previewLineLimit)
        let preview = visibleLines.isEmpty
            ? "No persisted JSONL yet."
            : visibleLines.joined(separator: "\n")

        await MainActor.run {
            previewText = preview
        }
    }

    private func emitInfoEvent() async {
        let logger = logging.logger(
            category: Constants.category,
            source: #fileID
        )
        logger.info("Demo info event")
        await MainActor.run {
            status = "Info event emitted"
        }
    }

    private func emitWarningEvent() async {
        let logger = logging.logger(
            category: Constants.category,
            source: #fileID
        )
        logger.warning(
            "Demo warning event",
            metadata: ["scope": "demo"]
        )
        await MainActor.run {
            status = "Warning event emitted"
        }
    }

    private func emitErrorEvent() async {
        let logger = logging.logger(
            category: Constants.category,
            source: #fileID
        )
        logger.error(
            "Demo error event",
            metadata: [
                "code": "E-DEMO-001",
                "hint": "open-console"
            ]
        )
        await MainActor.run {
            status = "Error event emitted"
        }
    }

    private func emitBatchEvents() async {
        let logger = logging.logger(
            category: Constants.category,
            source: #fileID
        )

        for index in 1...Constants.batchCount {
            await logger.logImmediately(
                .notice,
                "Batch event \(index)",
                metadata: ["batch": "\(index)"]
            )
        }

        await refreshPreview()
        await MainActor.run {
            status = "Batch events emitted"
        }
    }

    private func exportLatestEvents() async {
        let jsonLines = await logging.store.exportJSONLines(
            matching: .init(limit: Constants.exportLimit)
        )
        let copied = await MainActor.run {
            copyToClipboard(jsonLines)
        }
        await MainActor.run {
            status = copied
                ? "Copied latest 100 events as JSONL"
                : "Clipboard is not supported on this platform"
        }
    }

    private func clearAllLogs() async {
        await logging.clear()
        await refreshPreview()
        await MainActor.run {
            status = "Cleared in-memory and persisted logs"
        }
    }

    private func copyToClipboard(_ value: String) -> Bool {
        #if canImport(UIKit)
        UIPasteboard.general.string = value
        return true
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(value, forType: .string)
        #else
        _ = value
        return false
        #endif
    }
}
