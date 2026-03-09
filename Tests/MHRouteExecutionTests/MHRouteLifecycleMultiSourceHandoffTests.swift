import Foundation
import MHDeepLinking
import MHLogging
import MHPlatformTesting
import MHRouteExecution
import Testing

struct MHRouteLifecycleMultiSourceHandoffTests {
    @Test
    func submitLatest_fromSourceChain_consumesFirstAvailableURLAndAppliesRoute() async throws {
        let (logger, store) = makeLogger()
        let recorder = MHRouteExecutionRecorder<String>()
        let lifecycle = MHRouteLifecycle<Int>(
            logger: logger,
            initialReadiness: true,
            isDuplicate: ==
        )
        let emptySource = MHDeepLinkURLRecorder(initialURL: nil)
        let queuedSource = MHDeepLinkURLRecorder(
            initialURL: URL(string: "test://route/35")
        )
        let fallbackSource = MHDeepLinkURLRecorder(
            initialURL: URL(string: "test://route/88")
        )

        let outcome = try await lifecycle.submitLatest(
            from: MHDeepLinkSourceChain(
                emptySource,
                queuedSource,
                fallbackSource
            ),
            parse: Self.parseRoute(from:)
        ) { resolvedRoute in
            await recorder.record("apply:\(resolvedRoute)")
        }

        let appliedOutcome = try #require(outcome)
        expectApplied(
            appliedOutcome,
            expected: 35
        )
        #expect(await emptySource.consumeCountValue() == 1)
        #expect(await queuedSource.consumeCountValue() == 1)
        #expect(await fallbackSource.consumeCountValue() == 0)
        #expect(await recorder.values() == ["apply:35"])
        let events = await store.events()
        #expect(events.map(\.message) == [
            "accepted deep-link URL for route handling",
            "route applied"
        ])
    }

    @Test
    func submitLatest_fromVariadicSources_appliesRouteFromLaterAvailableSource() async throws {
        let (logger, store) = makeLogger()
        let recorder = MHRouteExecutionRecorder<String>()
        let lifecycle = MHRouteLifecycle<Int>(
            logger: logger,
            initialReadiness: true,
            isDuplicate: ==
        )
        let emptySource = MHDeepLinkURLRecorder(initialURL: nil)
        let queuedSource = MHDeepLinkURLRecorder(
            initialURL: URL(string: "test://route/64")
        )

        let outcome = try await lifecycle.submitLatest(
            from: emptySource,
            queuedSource,
            parse: Self.parseRoute(from:)
        ) { resolvedRoute in
            await recorder.record("apply:\(resolvedRoute)")
        }

        let appliedOutcome = try #require(outcome)
        expectApplied(
            appliedOutcome,
            expected: 64
        )
        #expect(await emptySource.consumeCountValue() == 1)
        #expect(await queuedSource.consumeCountValue() == 1)
        #expect(await recorder.values() == ["apply:64"])
        let events = await store.events()
        #expect(events.map(\.message) == [
            "accepted deep-link URL for route handling",
            "route applied"
        ])
    }
}

private extension MHRouteLifecycleMultiSourceHandoffTests {
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
            #fileID,
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
        case .applied(let route):
            #expect(route == expected)
        case .queued:
            Issue.record("Expected applied outcome, got queued.")
        case .deduplicated:
            Issue.record("Expected applied outcome, got deduplicated.")
        }
    }
}
