import Foundation
import MHLogging
import Testing

@MainActor
struct MHLoggingBootstrapTests {
    @Test
    func bootstrap_uses_explicit_capture_level_and_restores_persisted_logs() async {
        let fileManager = FileManager.default
        let directoryURL = temporaryDirectoryURL(name: "capture-level")
        defer {
            try? fileManager.removeItem(at: directoryURL)
        }

        let fileURL = directoryURL.appendingPathComponent("logs.jsonl")
        let bootstrap = MHLoggingBootstrap(
            captureLevel: .warning,
            subsystem: "tests.bootstrap",
            fileURL: fileURL,
            fileManager: fileManager
        )
        await bootstrap.waitForInitialLoad()

        let logger = bootstrap.logger(
            category: "CaptureLevel",
            source: #fileID
        )

        await logger.logImmediately(.info, "skip-info")
        await logger.logImmediately(.warning, "keep-warning")

        bootstrap.captureLevel = .info

        await logger.logImmediately(.info, "keep-info")

        let liveEvents = await bootstrap.store.events()
        #expect(liveEvents.map(\.message) == [
            "keep-warning",
            "keep-info"
        ])

        let restoredBootstrap = MHLoggingBootstrap(
            subsystem: "tests.bootstrap",
            fileURL: fileURL,
            fileManager: fileManager
        )
        await restoredBootstrap.waitForInitialLoad()

        #expect(restoredBootstrap.captureLevel == .warning)

        let restoredEvents = await restoredBootstrap.store.events()
        #expect(restoredEvents.map(\.message) == [
            "keep-warning",
            "keep-info"
        ])
    }

    @Test
    func bootstrap_capture_level_updates_runtime_state() async {
        let fileManager = FileManager.default
        let directoryURL = temporaryDirectoryURL(name: "runtime-state")
        defer {
            try? fileManager.removeItem(at: directoryURL)
        }

        let fileURL = directoryURL.appendingPathComponent("logs.jsonl")
        let bootstrap = MHLoggingBootstrap(
            captureLevel: .warning,
            subsystem: "tests.bootstrap",
            fileURL: fileURL,
            fileManager: fileManager
        )
        await bootstrap.waitForInitialLoad()

        let logger = bootstrap.logger(
            category: "CaptureLevel",
            source: #fileID
        )

        await logger.logImmediately(.info, "skip-info")
        bootstrap.captureLevel = .info
        await logger.logImmediately(.info, "keep-info")

        let events = await bootstrap.store.events()
        #expect(bootstrap.captureLevel == .info)
        #expect(events.map(\.message) == ["keep-info"])
    }

    @Test
    func bootstrap_clear_removes_memory_and_persisted_logs() async {
        let fileManager = FileManager.default
        let directoryURL = temporaryDirectoryURL(name: "clear")
        defer {
            try? fileManager.removeItem(at: directoryURL)
        }

        let fileURL = directoryURL.appendingPathComponent("logs.jsonl")
        let bootstrap = MHLoggingBootstrap(
            captureLevel: .debug,
            subsystem: "tests.bootstrap",
            fileURL: fileURL,
            fileManager: fileManager
        )
        await bootstrap.waitForInitialLoad()

        let logger = bootstrap.logger(
            category: "Clear",
            source: #fileID
        )
        await logger.logImmediately(.warning, "keep-warning")

        await bootstrap.clear()

        let restoredBootstrap = MHLoggingBootstrap(
            subsystem: "tests.bootstrap",
            fileURL: fileURL,
            fileManager: fileManager
        )
        await restoredBootstrap.waitForInitialLoad()

        let restoredEvents = await restoredBootstrap.store.events()
        #expect(restoredEvents.isEmpty)
    }
}

private extension MHLoggingBootstrapTests {
    func temporaryDirectoryURL(name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MHLoggingBootstrapTests")
            .appendingPathComponent(name)
            .appendingPathComponent(UUID().uuidString)
    }
}
