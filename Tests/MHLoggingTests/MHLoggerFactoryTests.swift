import MHLogging
import Testing

struct MHLoggerFactoryTests {
    @Test
    func factory_owned_store_uses_policy_subsystem_and_category() async {
        let factory = MHLoggerFactory(
            policy: .init(
                minimumLevel: .warning,
                persistsToDisk: false,
                maximumInMemoryEvents: 20,
                maximumDiskBytes: 1_000
            ),
            subsystem: "tests.factory"
        )
        let logger = factory.logger(
            category: "Billing",
            source: #fileID
        )

        await logger.logImmediately(.info, "skip-info")
        await logger.logImmediately(.error, "keep-error")

        let events = await factory.store.events()
        #expect(events.count == 1)
        #expect(events.first?.level == .error)
        #expect(events.first?.subsystem == "tests.factory")
        #expect(events.first?.category == "Billing")
    }

    @Test
    func factory_uses_source_as_default_category_when_category_is_omitted() async {
        let store = MHLogStore(
            policy: .init(
                minimumLevel: .debug,
                persistsToDisk: false,
                maximumInMemoryEvents: 20,
                maximumDiskBytes: 1_000
            )
        )
        let factory = MHLoggerFactory(
            store: store,
            policy: .debugDefault,
            subsystem: "tests.injected"
        )
        let logger = factory.logger(
            source: "Synthetic/InjectedLogger.swift"
        )

        await logger.logImmediately(.notice, "source-category")

        let event = await store.events().first
        #expect(event?.subsystem == "tests.injected")
        #expect(event?.category == "Synthetic/InjectedLogger.swift")
        #expect(event?.message == "source-category")
    }
}
