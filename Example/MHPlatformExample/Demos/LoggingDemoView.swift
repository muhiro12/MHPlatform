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

    private static let policy = MHLogPolicy.debugDefault

    private static let jsonFileURL: URL = {
        let baseURL = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first ?? .temporaryDirectory
        return baseURL
            .appendingPathComponent("mhplatform-example")
            .appendingPathComponent("logs.jsonl")
    }()

    private static let jsonSink = MHJSONLLogSink(
        fileURL: jsonFileURL,
        maximumFileSizeBytes: policy.maximumDiskBytes
    )

    private static let store = MHLogStore(
        policy: policy,
        sinks: [
            MHOSLogSink(),
            jsonSink
        ]
    )

    private let logger = MHLogger(
        #fileID,
        store: Self.store,
        subsystem: Constants.subsystem,
        category: Constants.category,
        policy: policy
    )

    @State private var previewText = "No persisted JSONL yet."
    @State private var status = "Emit samples or open the console for filtering."

    var body: some View {
        NavigationStack {
            List {
                emitSection
                actionsSection
                previewSection
                consoleSection
                statusSection
            }
            .navigationTitle("MHLogging")
            .task {
                await refreshPreview()
            }
        }
    }

    private var emitSection: some View {
        Section("Emit Sample Events") {
            Button("Emit Info") {
                emitInfoEvent()
            }
            Button("Emit Warning") {
                emitWarningEvent()
            }
            Button("Emit Error") {
                emitErrorEvent()
            }
            Button("Emit Batch") {
                emitBatchEvents()
            }
        }
    }

    private var actionsSection: some View {
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

    private var previewSection: some View {
        Section("Persisted JSONL Preview") {
            Text(previewText)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }

    private var consoleSection: some View {
        Section("Console") {
            NavigationLink("Open MHLogConsoleView") {
                MHLogConsoleView(store: Self.store)
            }
            Text("Use level/category/search filters in the console.")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }

    private var statusSection: some View {
        Section("Status") {
            Text(status)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }

    private func refreshPreview() async {
        let text = await Self.jsonSink.readJSONLines()
        let lines = text.split(whereSeparator: \.isNewline)
        let visibleLines = lines.suffix(Constants.previewLineLimit)
        let preview = visibleLines.isEmpty
            ? "No persisted JSONL yet."
            : visibleLines.joined(separator: "\n")

        await MainActor.run {
            previewText = preview
        }
    }

    private func emitInfoEvent() {
        logger.info("Demo info event")
        status = "Info event emitted"
    }

    private func emitWarningEvent() {
        logger.warning(
            "Demo warning event",
            metadata: ["scope": "demo"]
        )
        status = "Warning event emitted"
    }

    private func emitErrorEvent() {
        logger.error(
            "Demo error event",
            metadata: [
                "code": "E-DEMO-001",
                "hint": "open-console"
            ]
        )
        status = "Error event emitted"
    }

    private func emitBatchEvents() {
        Task {
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
    }

    private func exportLatestEvents() async {
        let jsonLines = await Self.store.exportJSONLines(
            matching: .init(limit: Constants.exportLimit)
        )
        let copied = copyToClipboard(jsonLines)
        await MainActor.run {
            status = copied
                ? "Copied latest 100 events as JSONL"
                : "Clipboard is not supported on this platform"
        }
    }

    private func clearAllLogs() async {
        await Self.store.clear()
        await Self.jsonSink.clear()
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
