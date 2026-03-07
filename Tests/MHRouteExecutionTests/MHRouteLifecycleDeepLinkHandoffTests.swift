import Foundation
@testable import MHDeepLinking
@testable import MHLogging
@testable import MHRouteExecution
import Testing

struct MHRouteLifecycleDeepLinkHandoffTests {
    @Test
    func submitLatest_fromInbox_returnsNilWithoutLoggingWhenNoPendingURLExists() async throws {
        let (logger, store) = makeLogger()
        let recorder = MHRouteExecutionEventRecorder()
        let lifecycle = MHRouteLifecycle<Int>(
            logger: logger,
            initialReadiness: true,
            isDuplicate: ==
        )
        let inbox = MHDeepLinkInbox()

        let outcome = try await lifecycle.submitLatest(
            from: inbox,
            parse: Self.parseRoute(from:)
        ) { resolvedRoute in
            await recorder.record("apply:\(resolvedRoute)")
        }

        #expect(outcome == nil)
        #expect(await recorder.events().isEmpty)
        #expect(await store.events().isEmpty)
    }

    @Test
    @MainActor
    func submitLatest_fromObservableInbox_appliesRouteAndClearsPendingURL() async throws {
        let (logger, store) = makeLogger()
        let recorder = MHRouteExecutionEventRecorder()
        let lifecycle = MHRouteLifecycle<Int>(
            logger: logger,
            initialReadiness: true,
            isDuplicate: ==
        )
        let inbox = MHObservableDeepLinkInbox()
        let url = try #require(URL(string: "test://route/12"))

        await inbox.ingest(url)
        #expect(inbox.pendingURL == url)

        let outcome = try await lifecycle.submitLatest(
            from: inbox,
            parse: Self.parseRoute(from:)
        ) { resolvedRoute in
            await recorder.record("apply:\(resolvedRoute)")
        }

        let appliedOutcome = try #require(outcome)
        expectApplied(
            appliedOutcome,
            expected: 12
        )
        #expect(inbox.pendingURL == nil)
        #expect(await recorder.events() == ["apply:12"])
        let events = await store.events()
        #expect(events.map(\.message) == [
            "accepted deep-link URL for route handling",
            "route applied"
        ])
    }

    @Test
    func submitLatest_fromStoreQueuesRouteAndExposesLifecycleState() async throws {
        let (logger, store) = makeLogger()
        let recorder = MHRouteExecutionEventRecorder()
        let lifecycle = MHRouteLifecycle<Int>(
            logger: logger,
            initialReadiness: false,
            isDuplicate: ==
        )
        let suiteName = "MHRouteLifecycleStoreSubmitLatestTests"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)

        let deepLinkStore = MHDeepLinkStore(
            userDefaults: userDefaults,
            key: "pendingRoute"
        )
        let url = try #require(URL(string: "test://route/21"))
        deepLinkStore.ingest(url)

        let queuedOutcome = try #require(
            try await lifecycle.submitLatest(
                from: deepLinkStore,
                parse: Self.parseRoute(from:)
            ) { resolvedRoute in
                await recorder.record("apply:\(resolvedRoute)")
            }
        )

        expectQueued(queuedOutcome)
        #expect(await lifecycle.hasPendingRoute)
        #expect(await lifecycle.isReady == false)

        await lifecycle.setReadiness(true)
        #expect(await lifecycle.isReady)

        let appliedOutcome = try #require(
            try await lifecycle.applyPendingIfReady { resolvedRoute in
                await recorder.record("apply:\(resolvedRoute)")
            }
        )

        expectApplied(
            appliedOutcome,
            expected: 21
        )
        #expect(await lifecycle.hasPendingRoute == false)
        #expect(await recorder.events() == ["apply:21"])
        let events = await store.events()
        #expect(events.map(\.message) == [
            "accepted deep-link URL for route handling",
            "route queued until execution becomes ready",
            "route applied"
        ])
    }

    @Test
    func submitLatest_fromInbox_logsParseFailureForInvalidURL() async throws {
        let (logger, store) = makeLogger()
        let recorder = MHRouteExecutionEventRecorder()
        let lifecycle = MHRouteLifecycle<Int>(
            logger: logger,
            initialReadiness: true,
            isDuplicate: ==
        )
        let inbox = MHDeepLinkInbox()
        let invalidURL = try #require(URL(string: "test://route/invalid"))

        await inbox.ingest(invalidURL)

        let outcome = try await lifecycle.submitLatest(
            from: inbox,
            parse: Self.parseRoute(from:)
        ) { resolvedRoute in
            await recorder.record("apply:\(resolvedRoute)")
        }

        #expect(outcome == nil)
        #expect(await recorder.events().isEmpty)
        let events = await store.events()
        #expect(events.map(\.message) == [
            "ignored deep-link URL because parsing failed"
        ])
    }
}

private extension MHRouteLifecycleDeepLinkHandoffTests {
    enum TestConstants {
        static let maximumInMemoryEvents = 20
        static let maximumDiskBytes = 1_000
    }

    static func parseRoute(from url: URL) -> Int? {
        Int(url.lastPathComponent)
    }

    func makeLogger() -> (MHLogger, MHLogStore) {
        let store = MHLogStore(
            policy: .init(
                minimumLevel: .debug,
                persistsToDisk: false,
                maximumInMemoryEvents: TestConstants.maximumInMemoryEvents,
                maximumDiskBytes: TestConstants.maximumDiskBytes
            )
        )
        let logger = MHLogger(
            "Tests/MHRouteLifecycleDeepLinkHandoffTests.swift",
            store: store,
            subsystem: "tests.route"
        )
        return (logger, store)
    }

    func expectApplied(
        _ outcome: MHRouteExecutionOutcome<Int>,
        expected: Int
    ) {
        switch outcome {
        case .queued:
            Issue.record("Expected applied outcome, got queued.")
        case .applied(let resolvedRoute):
            #expect(resolvedRoute == expected)
        case .deduplicated:
            Issue.record("Expected applied outcome, got deduplicated.")
        }
    }

    func expectQueued(_ outcome: MHRouteExecutionOutcome<Int>) {
        switch outcome {
        case .queued:
            break
        case .applied(let resolvedRoute):
            Issue.record("Expected queued outcome, got applied(\(resolvedRoute)).")
        case .deduplicated:
            Issue.record("Expected queued outcome, got deduplicated.")
        }
    }
}
