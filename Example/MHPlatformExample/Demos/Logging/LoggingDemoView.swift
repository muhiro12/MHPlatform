import MHPlatform
import SwiftUI

struct LoggingDemoView: View {
    private enum Constants {
        static let subsystem = "MHPlatformExample"
        static let category = "LoggingDemo"
        static let batchCount = 5
        static let snapshotStorageKeys = MHLogSnapshotStorageKeys(
            current: .init(
                storageKey: "mhplatform-example.logging.current-session"
            ),
            previous: .init(
                storageKey: "mhplatform-example.logging.previous-session"
            )
        )
    }

    @State private var logging = MHLoggingBootstrap(
        subsystem: Constants.subsystem,
        snapshotStorageKeys: Constants.snapshotStorageKeys
    )
    @State private var status = "Open the diagnostics console or emit sample events."

    var body: some View {
        NavigationStack {
            List {
                diagnosticsSection()
                emitSection()
                statusSection()
            }
            .navigationTitle("MHLogging")
            .task {
                await MainActor.run {
                    status = "Capture level: \(logging.captureLevel.name.uppercased())"
                }
            }
        }
    }

    private func diagnosticsSection() -> some View {
        @Bindable var logging = logging

        return Section("Diagnostics") {
            LabeledContent(
                "Capture Level",
                value: logging.captureLevel.name.uppercased()
            )
            NavigationLink("Open Diagnostics Console") {
                MHLogConsoleView(logging: logging)
            }
            Text(
                "The console can change capture level, inspect current and previous sessions, "
                    + "copy JSONL, export, and clear saved snapshots."
            )
            .foregroundStyle(.secondary)
            .font(.caption)
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

    private func statusSection() -> some View {
        Section("Status") {
            Text(status)
                .font(.caption.monospaced())
                .textSelection(.enabled)
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

        await MainActor.run {
            status = "Batch events emitted"
        }
    }
}
