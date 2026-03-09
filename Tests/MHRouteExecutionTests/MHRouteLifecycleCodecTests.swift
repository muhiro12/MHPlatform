import Foundation
import MHDeepLinking
import MHLogging
import MHPlatformTesting
import MHRouteExecution
import Testing

struct MHRouteLifecycleCodecTests {
    @Test
    func submit_usingCodec_appliesRoute() async throws {
        let (logger, logStore) = makeLogger()
        let recorder = MHRouteExecutionRecorder<String>()
        let lifecycle = MHRouteLifecycle<CodecRoute>(
            logger: logger,
            initialReadiness: true,
            isDuplicate: ==
        )

        let outcome = try await lifecycle.submit(
            try #require(URL(string: "test://route/7")),
            using: Self.codec
        ) { route in
            await recorder.record("apply:\(route.value)")
        }

        expectApplied(
            outcome,
            expected: 7
        )
        #expect(await recorder.values() == ["apply:7"])
        let events = await logStore.events()
        #expect(events.map(\.message) == [
            "accepted deep-link URL for route handling",
            "route applied"
        ])
    }

    @Test
    func submitLatest_usingCodec_fromStoreQueuesAndReplaysPendingRoute() async throws {
        let (logger, logStore) = makeLogger()
        let recorder = MHRouteExecutionRecorder<String>()
        let lifecycle = MHRouteLifecycle<CodecRoute>(
            logger: logger,
            initialReadiness: false,
            isDuplicate: ==
        )
        let suiteName = "MHRouteLifecycleCodecSubmitLatestTests"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)

        let deepLinkStore = MHDeepLinkStore(
            userDefaults: userDefaults,
            key: "pendingRoute"
        )
        deepLinkStore.ingest(
            try #require(URL(string: "test://route/21"))
        )

        let queuedOutcome = try await lifecycle.submitLatest(
            from: deepLinkStore,
            using: Self.codec
        ) { route in
            await recorder.record("apply:\(route.value)")
        }

        expectQueued(queuedOutcome)
        #expect(await lifecycle.hasPendingRoute)

        let replayedOutcome = try await lifecycle.activate { route in
            await recorder.record("apply:\(route.value)")
        }

        expectApplied(
            replayedOutcome,
            expected: 21
        )
        #expect(await lifecycle.hasPendingRoute == false)
        #expect(await recorder.values() == ["apply:21"])
        let events = await logStore.events()
        #expect(events.map(\.message) == [
            "accepted deep-link URL for route handling",
            "route queued until execution becomes ready",
            "route applied"
        ])
    }

    @Test
    func submitLatest_usingCodec_logsParseFailureForInvalidURL() async throws {
        let (logger, logStore) = makeLogger()
        let recorder = MHRouteExecutionRecorder<String>()
        let lifecycle = MHRouteLifecycle<CodecRoute>(
            logger: logger,
            initialReadiness: true,
            isDuplicate: ==
        )
        let inbox = MHDeepLinkInbox()
        await inbox.ingest(
            try #require(URL(string: "test://unknown/42"))
        )

        let outcome = try await lifecycle.submitLatest(
            from: inbox,
            using: Self.codec
        ) { route in
            await recorder.record("apply:\(route.value)")
        }

        #expect(outcome == nil)
        #expect(await recorder.values().isEmpty)
        let events = await logStore.events()
        #expect(events.map(\.message) == [
            "ignored deep-link URL because parsing failed"
        ])
    }

    @Test
    func submitLatest_usingCodec_fromSourceChain_appliesFirstAvailableRoute() async throws {
        let (logger, logStore) = makeLogger()
        let recorder = MHRouteExecutionRecorder<String>()
        let lifecycle = MHRouteLifecycle<CodecRoute>(
            logger: logger,
            initialReadiness: true,
            isDuplicate: ==
        )
        let emptySource = MHDeepLinkURLRecorder(initialURL: nil)
        let queuedSource = MHDeepLinkURLRecorder(
            initialURL: URL(string: "test://route/31")
        )
        let fallbackSource = MHDeepLinkURLRecorder(
            initialURL: URL(string: "test://route/99")
        )

        let outcome = try await lifecycle.submitLatest(
            from: MHDeepLinkSourceChain(
                emptySource,
                queuedSource,
                fallbackSource
            ),
            using: Self.codec
        ) { route in
            await recorder.record("apply:\(route.value)")
        }

        expectApplied(
            outcome,
            expected: 31
        )
        #expect(await emptySource.consumeCountValue() == 1)
        #expect(await queuedSource.consumeCountValue() == 1)
        #expect(await fallbackSource.consumeCountValue() == 0)
        #expect(await recorder.values() == ["apply:31"])
        let events = await logStore.events()
        #expect(events.map(\.message) == [
            "accepted deep-link URL for route handling",
            "route applied"
        ])
    }

    @Test
    func submitLatest_usingCodec_fromVariadicSources_stopsAtFirstAvailableURL() async throws {
        let (logger, logStore) = makeLogger()
        let recorder = MHRouteExecutionRecorder<String>()
        let lifecycle = MHRouteLifecycle<CodecRoute>(
            logger: logger,
            initialReadiness: true,
            isDuplicate: ==
        )
        let invalidSource = MHDeepLinkURLRecorder(
            initialURL: URL(string: "test://unknown/42")
        )
        let validSource = MHDeepLinkURLRecorder(
            initialURL: URL(string: "test://route/42")
        )

        let outcome = try await lifecycle.submitLatest(
            from: invalidSource,
            validSource,
            using: Self.codec
        ) { route in
            await recorder.record("apply:\(route.value)")
        }

        #expect(outcome == nil)
        #expect(await invalidSource.consumeCountValue() == 1)
        #expect(await validSource.consumeCountValue() == 0)
        #expect(await recorder.values().isEmpty)
        let events = await logStore.events()
        #expect(events.map(\.message) == [
            "ignored deep-link URL because parsing failed"
        ])
    }
}

private extension MHRouteLifecycleCodecTests {
    enum TestConstants {
        static let maximumInMemoryEvents = 20
        static let maximumDiskBytes = 1_000
        static let routePathComponentCount = 2
    }

    enum CodecRoute: Equatable, Sendable, MHDeepLinkRoute {
        case route(Int)

        var value: Int {
            switch self {
            case .route(let value):
                return value
            }
        }

        var deepLinkDescriptor: MHDeepLinkDescriptor {
            switch self {
            case .route(let value):
                return .init(
                    pathComponents: [
                        "route",
                        String(value)
                    ]
                )
            }
        }

        init?(deepLinkDescriptor: MHDeepLinkDescriptor) {
            guard deepLinkDescriptor.pathComponents.count == TestConstants.routePathComponentCount,
                  deepLinkDescriptor.pathComponents[0] == "route",
                  let value = Int(deepLinkDescriptor.pathComponents[1]) else {
                return nil
            }

            self = .route(value)
        }
    }

    static var codec: MHDeepLinkCodec<CodecRoute> {
        .init(
            configuration: .init(
                customScheme: "test",
                preferredUniversalLinkHost: "example.com",
                allowedUniversalLinkHosts: ["example.com"],
                universalLinkPathPrefix: "MHPlatform",
                preferredTransport: .customScheme
            )
        )
    }

    func makeLogger() -> (MHLogger, MHLogStore) {
        let logStore = MHLogStore(
            policy: .init(
                minimumLevel: .debug,
                persistsToDisk: false,
                maximumInMemoryEvents: TestConstants.maximumInMemoryEvents,
                maximumDiskBytes: TestConstants.maximumDiskBytes
            )
        )
        let logger = MHLogger(
            #fileID,
            store: logStore,
            subsystem: "tests.route"
        )
        return (logger, logStore)
    }

    func expectApplied(
        _ outcome: MHRouteExecutionOutcome<CodecRoute>?,
        expected: Int
    ) {
        switch outcome {
        case .queued:
            Issue.record("Expected applied outcome, got queued.")
        case .applied(let route):
            #expect(route == .route(expected))
        case nil:
            Issue.record("Expected applied outcome, got nil.")
        case .deduplicated:
            Issue.record("Expected applied outcome, got deduplicated.")
        }
    }

    func expectQueued(_ outcome: MHRouteExecutionOutcome<CodecRoute>?) {
        switch outcome {
        case .queued:
            break
        case .applied(let route):
            Issue.record("Expected queued outcome, got applied(\(route.value)).")
        case nil:
            Issue.record("Expected queued outcome, got nil.")
        case .deduplicated:
            Issue.record("Expected queued outcome, got deduplicated.")
        }
    }
}
