import Foundation
import MHPlatform
import SwiftData
import SwiftUI

struct PersistenceMaintenanceDemoView: View {
    @State private var relocationStatus = "No relocation run yet"
    @State private var cleanupStatus = "No cleanup run yet"
    @State private var resetStatus = "No reset run yet"
    @State private var shouldFailReset = false
    @State private var resetEvents = [String]()

    var body: some View {
        NavigationStack {
            List {
                relocationSection
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

    struct RelocationFixture {
        let sandboxURL: URL
        let legacyStoreURL: URL
        let currentStoreURL: URL
        let currentDirectoryURL: URL
        let storeFileName: String
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

    var relocationSection: some View {
        Section("Store relocation") {
            Button("Run relocation demo") {
                do {
                    let status = try runRelocationDemo()
                    relocationStatus = status
                } catch {
                    relocationStatus = "Failed: \(error.localizedDescription)"
                }
            }

            Text(relocationStatus)
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

    nonisolated
    static func validateRelocatedStore(
        storeURL: URL
    ) throws {
        let validationConfiguration = ModelConfiguration(url: storeURL)
        _ = try ModelContainer(
            for: PersistenceMaintenanceDemoRecord.self,
            configurations: validationConfiguration
        )
    }

    func runRelocationDemo() throws -> String {
        let fileManager: FileManager = .default
        let fixture = try makeRelocationFixture(fileManager: fileManager)

        defer {
            try? fileManager.removeItem(at: fixture.sandboxURL)
        }

        try seedLegacyStore(
            storeURL: fixture.legacyStoreURL
        )
        seedCurrentStaleFiles(
            fixture: fixture,
            fileManager: fileManager
        )

        let currentConfiguration = ModelConfiguration(url: fixture.currentStoreURL)
        let result = try MHStoreRelocationService.relocateIfNeeded(
            plan: .init(
                legacyStoreURL: fixture.legacyStoreURL,
                currentStoreURL: currentConfiguration.url
            ),
            fileManager: fileManager
        ) { relocatedStoreURL, _ in
            try Self.validateRelocatedStore(
                storeURL: relocatedStoreURL
            )
        }

        return switch result {
        case let .relocated(copiedFileNames, removedCurrentFileNames):
            "relocated copied=\(copiedFileNames) removedCurrent=\(removedCurrentFileNames)"
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

        let result = try MHStoreRelocationService.removeLegacyStoreFilesIfNeeded(
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

    func makeRelocationFixture(
        fileManager: FileManager
    ) throws -> RelocationFixture {
        let sandboxURL = fileManager.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        let legacyDirectoryURL = sandboxURL.appendingPathComponent("legacy", isDirectory: true)
        let currentDirectoryURL = sandboxURL.appendingPathComponent("current", isDirectory: true)
        let storeFileName = "Demo.store"

        try fileManager.createDirectory(at: legacyDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: currentDirectoryURL, withIntermediateDirectories: true)

        return .init(
            sandboxURL: sandboxURL,
            legacyStoreURL: legacyDirectoryURL.appendingPathComponent(storeFileName),
            currentStoreURL: currentDirectoryURL.appendingPathComponent(storeFileName),
            currentDirectoryURL: currentDirectoryURL,
            storeFileName: storeFileName
        )
    }

    func seedLegacyStore(
        storeURL: URL
    ) throws {
        let legacyConfiguration = ModelConfiguration(url: storeURL)
        let legacyContainer = try ModelContainer(
            for: PersistenceMaintenanceDemoRecord.self,
            configurations: legacyConfiguration
        )
        let legacyContext = ModelContext(legacyContainer)
        legacyContext.insert(
            PersistenceMaintenanceDemoRecord(value: "legacy")
        )
        try legacyContext.save()
    }

    func seedCurrentStaleFiles(
        fixture: RelocationFixture,
        fileManager: FileManager
    ) {
        _ = fileManager.createFile(
            atPath: fixture.currentStoreURL.path,
            contents: Data("stale".utf8)
        )
        _ = fileManager.createFile(
            atPath: fixture.currentDirectoryURL.appendingPathComponent(
                "\(fixture.storeFileName)-shm"
            ).path,
            contents: Data("stale-shm".utf8)
        )
    }
}

#Preview {
    PersistenceMaintenanceDemoView()
}
