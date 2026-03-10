import Foundation
import MHPlatform
import SwiftUI

struct PersistenceMaintenanceDemoView: View {
    @State private var migrationStatus = "No migration run yet"
    @State private var cleanupStatus = "No cleanup run yet"
    @State private var resetStatus = "No reset run yet"
    @State private var shouldFailReset = false
    @State private var resetEvents = [String]()

    var body: some View {
        NavigationStack {
            List {
                migrationSection
                cleanupSection
                resetSection
            }
            .navigationTitle("Persistence")
        }
    }
}

private extension PersistenceMaintenanceDemoView {
    enum DemoError: Error {
        case simulatedResetFailure
    }

    final class EventRecorder: @unchecked Sendable {
        private let lock = NSLock()
        nonisolated(unsafe) private var values = [String]()

        nonisolated
        func append(_ value: String) {
            lock.lock()
            values.append(value)
            lock.unlock()
        }

        nonisolated
        func snapshot() -> [String] {
            lock.lock()
            defer {
                lock.unlock()
            }
            return values
        }
    }

    var migrationSection: some View {
        Section("Store migration") {
            Button("Run migration demo") {
                do {
                    let status = try runMigrationDemo()
                    migrationStatus = status
                } catch {
                    migrationStatus = "Failed: \(error.localizedDescription)"
                }
            }
            Text(migrationStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    var cleanupSection: some View {
        Section("Legacy cleanup") {
            Button("Run cleanup demo") {
                do {
                    let status = try runCleanupDemo()
                    cleanupStatus = status
                } catch {
                    cleanupStatus = "Failed: \(error.localizedDescription)"
                }
            }
            Text(cleanupStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    var resetSection: some View {
        Section("Destructive reset") {
            Toggle("Simulate step failure", isOn: $shouldFailReset)

            Button("Run reset demo") {
                Task {
                    let result = await runResetDemo(shouldFail: shouldFailReset)
                    resetStatus = result
                }
            }

            Text(resetStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if resetEvents.isEmpty == false {
                ForEach(resetEvents, id: \.self) { event in
                    Text(event)
                        .font(.footnote)
                }
            }
        }
    }

    nonisolated
    static func eventDescription(_ event: MHDestructiveResetEvent) -> String {
        switch event {
        case .stepStarted(let name):
            return "stepStarted(\(name))"
        case .stepSucceeded(let name):
            return "stepSucceeded(\(name))"
        case let .stepFailed(name, message):
            return "stepFailed(\(name)): \(message)"
        case .completed:
            return "completed"
        }
    }

    func runMigrationDemo() throws -> String {
        let fileManager: FileManager = .default
        let sandboxURL = fileManager.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        let legacyDirectoryURL = sandboxURL.appendingPathComponent("legacy", isDirectory: true)
        let currentDirectoryURL = sandboxURL.appendingPathComponent("current", isDirectory: true)
        let storeFileName = "Demo.store"

        try fileManager.createDirectory(at: legacyDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: currentDirectoryURL, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: sandboxURL)
        }

        let legacyStoreURL = legacyDirectoryURL.appendingPathComponent(storeFileName)
        let currentStoreURL = currentDirectoryURL.appendingPathComponent(storeFileName)

        _ = fileManager.createFile(atPath: legacyStoreURL.path, contents: Data("legacy".utf8))
        _ = fileManager.createFile(
            atPath: legacyDirectoryURL.appendingPathComponent("\(storeFileName)-wal").path,
            contents: Data("legacy-wal".utf8)
        )
        _ = fileManager.createFile(
            atPath: currentStoreURL.path,
            contents: Data("stale".utf8)
        )
        _ = fileManager.createFile(
            atPath: currentDirectoryURL.appendingPathComponent("\(storeFileName)-shm").path,
            contents: Data("stale-shm".utf8)
        )

        let result = try MHStoreMigrator.migrateIfNeeded(
            plan: .init(
                legacyStoreURL: legacyStoreURL,
                currentStoreURL: currentStoreURL
            ),
            fileManager: fileManager
        )

        return switch result {
        case let .migrated(copiedFileNames, removedCurrentFileNames):
            "migrated copied=\(copiedFileNames) removedCurrent=\(removedCurrentFileNames)"
        case let .skipped(reason):
            "skipped reason=\(reason)"
        }
    }

    func runCleanupDemo() throws -> String {
        let fileManager: FileManager = .default
        let sandboxURL = fileManager.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        let legacyDirectoryURL = sandboxURL.appendingPathComponent("legacy", isDirectory: true)
        let currentDirectoryURL = sandboxURL.appendingPathComponent("current", isDirectory: true)
        let storeFileName = "Demo.store"

        try fileManager.createDirectory(at: legacyDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: currentDirectoryURL, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: sandboxURL)
        }

        let legacyStoreURL = legacyDirectoryURL.appendingPathComponent(storeFileName)
        let currentStoreURL = currentDirectoryURL.appendingPathComponent(storeFileName)

        _ = fileManager.createFile(atPath: legacyStoreURL.path, contents: Data())
        _ = fileManager.createFile(
            atPath: legacyDirectoryURL.appendingPathComponent("\(storeFileName)-shm").path,
            contents: Data()
        )
        _ = fileManager.createFile(atPath: currentStoreURL.path, contents: Data())

        let result = try MHStoreMigrator.removeLegacyStoreFilesIfNeeded(
            plan: .init(
                legacyStoreURL: legacyStoreURL,
                currentStoreURL: currentStoreURL
            ),
            fileManager: fileManager
        )

        return switch result {
        case let .removed(fileNames):
            "removed legacy files=\(fileNames)"
        case let .skipped(reason):
            "skipped reason=\(reason)"
        }
    }

    func runResetDemo(shouldFail: Bool) async -> String {
        let recorder = Self.EventRecorder()

        let outcome = await MHDestructiveResetService.run(
            steps: [
                .init(name: "clear-cache") {
                    // no-op
                },
                .init(name: "delete-store") {
                    if shouldFail {
                        throw DemoError.simulatedResetFailure
                    }
                },
                .init(name: "rebuild-index") {
                    // no-op
                }
            ]
        ) { event in
            recorder.append(
                Self.eventDescription(event)
            )
        }

        resetEvents = recorder.snapshot()

        switch outcome {
        case .succeeded(let completedSteps):
            return "succeeded completed=\(completedSteps)"
        case let .failed(error, failedStep, completedSteps):
            return "failed step=\(failedStep) completed=\(completedSteps) error=\(error)"
        }
    }
}

#Preview {
    PersistenceMaintenanceDemoView()
}
