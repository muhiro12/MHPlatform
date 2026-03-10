import Foundation
import MHAppRuntime
@testable import MHAppRuntimeCore
import MHLogging
import MHPlatformTesting
import MHRouteExecution
import SwiftUI
import Testing

struct MHAppRoutePipelineTests {
    @MainActor
    @Test
    func common_tasks_are_reused_across_startup_and_active_phases_in_order() async {
        var events = [String]()

        let runtime = makeRuntime { _ in
            events.append("startStore")
        }
        let lifecycle = MHAppRuntimeLifecycle(
            runtime: runtime,
            plan: .init(
                commonTasks: [
                    .init(name: "syncSubscriptionState") {
                        events.append("common.syncSubscriptionState")
                    },
                    .init(name: "refreshConfiguration") {
                        events.append("common.refreshConfiguration")
                    }
                ],
                startupTasks: [
                    .init(name: "updateNotifications") {
                        events.append("startup.updateNotifications")
                    }
                ],
                activeTasks: [
                    .init(name: "requestReview") {
                        events.append("active.requestReview")
                    }
                ],
                skipFirstActivePhase: true
            )
        )

        await lifecycle.handleInitialAppearance()
        await lifecycle.handleScenePhase(.active)
        await lifecycle.handleScenePhase(.inactive)
        await lifecycle.handleScenePhase(.active)

        #expect(
            events == [
                "startStore",
                "common.syncSubscriptionState",
                "common.refreshConfiguration",
                "startup.updateNotifications",
                "common.syncSubscriptionState",
                "common.refreshConfiguration",
                "active.requestReview"
            ]
        )
    }

    @MainActor
    @Test
    func activateIfNeeded_replays_queued_route() async throws {
        let routeRecorder = MHRouteExecutionRecorder<String>()
        let routeLifecycle = MHRouteLifecycle<Int>(
            logger: makeLogger(),
            initialReadiness: false,
            isDuplicate: ==
        )
        let pipeline = MHAppRoutePipeline(
            routeLifecycle: routeLifecycle,
            parse: Self.parseRoute(from:)
        ) { resolvedRoute in
            await routeRecorder.record("apply:\(resolvedRoute)")
        }

        let queuedOutcome = try await routeLifecycle.submit(7) { _ in
            Issue.record("Queued route should not execute before activation.")
        }
        expectQueued(queuedOutcome)

        let activationOutcome = try #require(await pipeline.activateIfNeeded())

        expectApplied(
            activationOutcome,
            expected: 7
        )
        #expect(await routeLifecycle.isReady)
        #expect(await routeRecorder.values() == ["apply:7"])
    }

    @MainActor
    @Test
    func drainPendingRoutesIfNeeded_prioritizes_pending_sources_before_pipeline_inbox() async throws {
        let routeRecorder = MHRouteExecutionRecorder<String>()
        let firstSource = MHDeepLinkURLRecorder(initialURL: nil)
        let secondSource = MHDeepLinkURLRecorder(
            initialURL: URL(string: "test://route/42")
        )
        let routeLifecycle = MHRouteLifecycle<Int>(
            logger: makeLogger(),
            initialReadiness: true,
            isDuplicate: ==
        )
        let pipeline = MHAppRoutePipeline(
            routeLifecycle: routeLifecycle,
            parse: Self.parseRoute(from:),
            pendingSources: [
                firstSource,
                secondSource
            ]
        ) { resolvedRoute in
            await routeRecorder.record("apply:\(resolvedRoute)")
        }

        let inboxURL = try #require(URL(string: "test://route/99"))
        await pipeline.ingest(inboxURL)

        let firstOutcome = try #require(await pipeline.drainPendingRoutesIfNeeded())

        expectApplied(
            firstOutcome,
            expected: 42
        )
        #expect(await firstSource.consumeCountValue() == 1)
        #expect(await secondSource.consumeCountValue() == 1)
        #expect(pipeline.inbox.pendingURL?.absoluteString == inboxURL.absoluteString)

        let secondOutcome = try #require(await pipeline.drainPendingRoutesIfNeeded())

        expectApplied(
            secondOutcome,
            expected: 99
        )
        #expect(await firstSource.consumeCountValue() == 2)
        #expect(await secondSource.consumeCountValue() == 2)
        #expect(pipeline.inbox.pendingURL == nil)
        #expect(await routeRecorder.values() == [
            "apply:42",
            "apply:99"
        ])
    }

    @MainActor
    @Test
    func drainPendingRoutesIfNeeded_consumes_only_one_pending_url_per_call() async throws {
        let routeRecorder = MHRouteExecutionRecorder<String>()
        let firstSource = MHDeepLinkURLRecorder(
            initialURL: URL(string: "test://route/12")
        )
        let secondSource = MHDeepLinkURLRecorder(
            initialURL: URL(string: "test://route/34")
        )
        let routeLifecycle = MHRouteLifecycle<Int>(
            logger: makeLogger(),
            initialReadiness: true,
            isDuplicate: ==
        )
        let pipeline = MHAppRoutePipeline(
            routeLifecycle: routeLifecycle,
            parse: Self.parseRoute(from:),
            pendingSources: [
                firstSource,
                secondSource
            ]
        ) { resolvedRoute in
            await routeRecorder.record("apply:\(resolvedRoute)")
        }

        let firstOutcome = try #require(await pipeline.drainPendingRoutesIfNeeded())

        expectApplied(
            firstOutcome,
            expected: 12
        )
        #expect(await firstSource.consumeCountValue() == 1)
        #expect(await secondSource.consumeCountValue() == 0)
        #expect(await routeRecorder.values() == ["apply:12"])

        let secondOutcome = try #require(await pipeline.drainPendingRoutesIfNeeded())

        expectApplied(
            secondOutcome,
            expected: 34
        )
        #expect(await secondSource.consumeCountValue() == 1)
        #expect(await routeRecorder.values() == [
            "apply:12",
            "apply:34"
        ])
    }

    @MainActor
    @Test
    func routeInbox_init_drains_pending_route_into_observable_route_inbox() async throws {
        let routeInbox = MHObservableRouteInbox<Int>()
        let pendingSource = MHDeepLinkURLRecorder(
            initialURL: URL(string: "test://route/21")
        )
        let routeLifecycle = MHRouteLifecycle<Int>(
            logger: makeLogger(),
            initialReadiness: true,
            isDuplicate: ==
        )
        let pipeline = MHAppRoutePipeline(
            routeLifecycle: routeLifecycle,
            parse: Self.parseRoute(from:),
            routeInbox: routeInbox,
            pendingSources: [pendingSource],
            )

        let outcome = try #require(await pipeline.drainPendingRoutesIfNeeded())

        expectApplied(
            outcome,
            expected: 21
        )
        #expect(routeInbox.pendingRoute == 21)
        #expect(routeInbox.consumeLatest() == 21)
        #expect(routeInbox.pendingRoute == nil)
    }

    @MainActor
    @Test
    func drainPendingRoutesIfNeeded_retains_latest_parse_failure_until_cleared() async throws {
        let invalidURL = try #require(URL(string: "test://route/not-an-int"))
        let validURL = try #require(URL(string: "test://route/55"))
        var appliedRoutes = [Int]()
        let routeLifecycle = MHRouteLifecycle<Int>(
            logger: makeLogger(),
            initialReadiness: true,
            isDuplicate: ==
        )
        let pendingSource = MHDeepLinkURLRecorder(
            initialURL: invalidURL
        )
        let pipeline = MHAppRoutePipeline(
            routeLifecycle: routeLifecycle,
            parse: Self.parseRoute(from:),
            pendingSources: [pendingSource]
        ) { route in
            appliedRoutes.append(route)
        }

        let invalidOutcome = await pipeline.drainPendingRoutesIfNeeded()

        #expect(invalidOutcome == nil)
        #expect(pipeline.lastParseFailureURL?.absoluteString == invalidURL.absoluteString)
        #expect(appliedRoutes.isEmpty)

        await pipeline.ingest(validURL)
        let validOutcome = try #require(await pipeline.drainPendingRoutesIfNeeded())

        expectApplied(
            validOutcome,
            expected: 55
        )
        #expect(appliedRoutes == [55])
        #expect(pipeline.lastParseFailureURL?.absoluteString == invalidURL.absoluteString)

        pipeline.clearLastParseFailure()

        #expect(pipeline.lastParseFailureURL == nil)
    }
}

private extension MHAppRoutePipelineTests {
    enum TestConstants {
        static let maximumInMemoryEvents = 20
        static let maximumDiskBytes = 1_000
    }

    static func parseRoute(from url: URL) -> Int? {
        Int(url.lastPathComponent)
    }

    func makeLogger() -> MHLogger {
        let store = MHLogStore(
            policy: .init(
                minimumLevel: .debug,
                persistsToDisk: false,
                maximumInMemoryEvents: TestConstants.maximumInMemoryEvents,
                maximumDiskBytes: TestConstants.maximumDiskBytes
            )
        )
        return .init(
            #fileID,
            store: store,
            subsystem: "tests.runtime"
        )
    }

    @MainActor
    func makeRuntime(
        startStore: @escaping MHAppRuntime.StartStore
    ) -> MHAppRuntime {
        .init(
            configuration: .init(
                subscriptionProductIDs: ["premium.monthly"]
            ),
            preferenceStore: .init(),
            startStore: startStore,
            subscriptionSectionViewBuilder: {
                AnyView(EmptyView())
            },
            startAds: nil,
            nativeAdViewBuilder: nil
        )
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

    func expectQueued(_ outcome: MHRouteExecutionOutcome<Int>) {
        switch outcome {
        case .queued:
            break
        case .applied(let route):
            Issue.record("Expected queued outcome, got applied(\(route)).")
        case .deduplicated:
            Issue.record("Expected queued outcome, got deduplicated.")
        }
    }
}
