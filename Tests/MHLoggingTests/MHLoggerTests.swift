import Foundation
@testable import MHLogging
import Testing

struct MHLoggerTests {
    @Test
    func loggerFactory_shares_store_policy_and_subsystem_override() async {
        let factory = MHLoggerFactory(
            policy: .init(
                minimumLevel: .debug,
                persistsToDisk: false,
                maximumInMemoryEvents: 20,
                maximumDiskBytes: 1_000
            ),
            subsystem: "tests.factory"
        )
        let firstLogger = factory.logger(
            category: "First",
            source: "Synthetic/First.swift"
        )
        let secondLogger = factory.logger(
            category: "Second",
            source: "Synthetic/Second.swift"
        )

        await firstLogger.logImmediately(.info, "first")
        await secondLogger.logImmediately(.notice, "second")

        let events = await factory.store.events()
        #expect(factory.policy.minimumLevel == .debug)
        #expect(factory.subsystem == "tests.factory")
        #expect(events.map(\.message) == ["first", "second"])
        #expect(events.map(\.subsystem) == ["tests.factory", "tests.factory"])
        #expect(events.map(\.category) == ["First", "Second"])
    }

    @Test
    func logger_policy_filters_lower_severity() async {
        let store = MHLogStore(
            policy: .init(
                minimumLevel: .debug,
                persistsToDisk: false,
                maximumInMemoryEvents: 20,
                maximumDiskBytes: 1_000
            )
        )
        let logger = MHLogger(
            #fileID,
            store: store,
            subsystem: "tests.logger",
            policy: .init(
                minimumLevel: .warning,
                persistsToDisk: false,
                maximumInMemoryEvents: 20,
                maximumDiskBytes: 1_000
            )
        )

        await logger.logImmediately(.info, "skip-info")
        await logger.logImmediately(.error, "keep-error")

        let events = await store.events()
        #expect(events.count == 1)
        #expect(events.first?.level == .error)
        #expect(events.first?.message == "keep-error")
    }

    @Test
    func logImmediately_captures_source_metadata() async {
        let store = MHLogStore(
            policy: .init(
                minimumLevel: .debug,
                persistsToDisk: false,
                maximumInMemoryEvents: 20,
                maximumDiskBytes: 1_000
            )
        )
        let logger = MHLogger(
            #fileID,
            store: store,
            subsystem: "tests.logger",
            )

        await logger.logImmediately(
            .warning,
            "source-check",
            metadata: ["code": "W1001"],
            file: "CustomFile.swift",
            function: "customFunction()",
            line: 88
        )

        let event = await store.events().first
        #expect(event?.source.file == "CustomFile.swift")
        #expect(event?.source.function == "customFunction()")
        #expect(event?.source.line == 88)
        #expect(event?.metadata["code"] == "W1001")
        #expect(event?.category == #fileID)
    }
}
