import Foundation
import MHLogging
import Testing

struct MHLogStoreTests {
    @Test
    func stores_ring_buffer_with_latest_wins() async {
        let policy = MHLogPolicy(
            minimumLevel: .debug,
            persistsToDisk: false,
            maximumInMemoryEvents: 3,
            maximumDiskBytes: 1_000
        )
        let store = MHLogStore(policy: policy)

        await store.record(makeEvent(index: 1, level: .debug))
        await store.record(makeEvent(index: 2, level: .info))
        await store.record(makeEvent(index: 3, level: .notice))
        await store.record(makeEvent(index: 4, level: .warning))

        let events = await store.events()
        #expect(events.count == 3)
        #expect(events.map(\.message) == ["message-2", "message-3", "message-4"])
    }

    @Test
    func filters_by_level_category_search_and_limit() async {
        let policy = MHLogPolicy(
            minimumLevel: .debug,
            persistsToDisk: false,
            maximumInMemoryEvents: 20,
            maximumDiskBytes: 1_000
        )
        let store = MHLogStore(policy: policy)

        await store.record(
            makeEvent(
                index: 1,
                level: .info,
                category: "billing",
                message: "Invoice created"
            )
        )
        await store.record(
            makeEvent(
                index: 2,
                level: .error,
                category: "billing",
                message: "Invoice failed",
                metadata: ["code": "E1001"]
            )
        )
        await store.record(
            makeEvent(
                index: 3,
                level: .critical,
                category: "sync",
                message: "Sync failed",
                metadata: ["code": "E2001"]
            )
        )

        let query = MHLogQuery(
            minimumLevel: .error,
            category: "billing",
            searchText: "failed",
            limit: 1
        )
        let filteredEvents = await store.events(matching: query)

        #expect(filteredEvents.count == 1)
        #expect(filteredEvents.first?.message == "Invoice failed")
    }

    @Test
    func exports_query_result_as_jsonl() async throws {
        let policy = MHLogPolicy(
            minimumLevel: .debug,
            persistsToDisk: false,
            maximumInMemoryEvents: 20,
            maximumDiskBytes: 1_000
        )
        let store = MHLogStore(policy: policy)

        await store.record(makeEvent(index: 1, level: .info))
        await store.record(makeEvent(index: 2, level: .warning))

        let jsonLines = await store.exportJSONLines(
            matching: .init(minimumLevel: .warning)
        )

        let lines = jsonLines.split(whereSeparator: \.isNewline)
        #expect(lines.count == 1)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(
            MHLogEvent.self,
            from: Data(lines[0].utf8)
        )
        #expect(event.level == .warning)
        #expect(event.message == "message-2")
    }
}

private extension MHLogStoreTests {
    func makeEvent(
        index: Int,
        level: MHLogLevel,
        category: String = "test",
        message: String? = nil,
        metadata: [String: String] = [:]
    ) -> MHLogEvent {
        MHLogEvent(
            level: level,
            subsystem: "tests.store",
            category: category,
            message: message ?? "message-\(index)",
            source: .init(
                file: "MHLogStoreTests.swift",
                function: "makeEvent",
                line: index
            ),
            timestamp: .init(timeIntervalSince1970: Double(index)),
            metadata: metadata
        )
    }
}
