import Foundation
import MHLogging
import Testing

@MainActor
struct MHLoggingBootstrapTests {
    @Test
    func bootstrap_switches_runtime_mode_and_restores_persisted_logs() async {
        let fileManager = FileManager.default
        let directoryURL = temporaryDirectoryURL(name: "runtime-mode")
        defer {
            try? fileManager.removeItem(at: directoryURL)
        }

        let fileURL = directoryURL.appendingPathComponent("logs.jsonl")
        let bootstrap = MHLoggingBootstrap(
            isDebugMode: false,
            subsystem: "tests.bootstrap",
            fileURL: fileURL,
            fileManager: fileManager
        )
        await bootstrap.waitForInitialLoad()

        let logger = bootstrap.logger(
            category: "Runtime",
            source: #fileID
        )

        await logger.logImmediately(.info, "skip-info")
        await logger.logImmediately(.warning, "keep-warning")

        bootstrap.isDebugMode = true

        await logger.logImmediately(.debug, "keep-debug")
        await logger.logImmediately(.info, "keep-info")

        let liveEvents = await bootstrap.store.events()
        #expect(liveEvents.map(\.message) == [
            "keep-warning",
            "keep-debug",
            "keep-info"
        ])

        let restoredBootstrap = MHLoggingBootstrap(
            isDebugMode: false,
            subsystem: "tests.bootstrap",
            fileURL: fileURL,
            fileManager: fileManager
        )
        await restoredBootstrap.waitForInitialLoad()

        let restoredEvents = await restoredBootstrap.store.events()
        #expect(restoredEvents.map(\.message) == [
            "keep-warning",
            "keep-debug",
            "keep-info"
        ])
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
            isDebugMode: true,
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
            isDebugMode: false,
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
