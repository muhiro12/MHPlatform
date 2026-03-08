import Foundation
@testable import MHAppRuntime
import MHDeepLinking
import MHLogging
import MHMutationFlow
import MHNotificationPayloads
import MHPlatformTesting
import MHPreferences
import MHRouteExecution
import SwiftUI
import Testing

extension MHPlatformIntegrationTests {
    static let codec = MHDeepLinkCodec<IntegrationRoute>(
        configuration: .init(
            customScheme: "integration",
            preferredUniversalLinkHost: "example.com",
            allowedUniversalLinkHosts: ["example.com"],
            universalLinkPathPrefix: "MHPlatform",
            preferredTransport: .customScheme
        )
    )

    nonisolated static func describe(
        _ source: MHNotificationRouteDeliveryOutcome.Source
    ) -> String {
        switch source {
        case .payload:
            return "payload"
        case .fallback:
            return "fallback"
        case .noRoute:
            return "noRoute"
        }
    }

    nonisolated static func describe(
        _ event: MHMutationEvent<String>
    ) -> String {
        switch event {
        case let .started(mutation, attempt):
            return "mutation.event.started:\(mutation):\(attempt)"
        case let .progress(progress):
            return describe(progress)
        case let .succeeded(value, attempts, _):
            return "mutation.event.succeeded:\(value):\(attempts)"
        case let .failed(_, attempts, _, isRecoverable):
            return "mutation.event.failed:\(attempts):\(isRecoverable)"
        case let .cancelled(attempts, _):
            return "mutation.event.cancelled:\(attempts)"
        }
    }

    nonisolated static func describe(
        _ progress: MHMutationProgress
    ) -> String {
        switch progress {
        case let .retryScheduled(nextAttempt, _):
            return "mutation.event.retryScheduled:\(nextAttempt)"
        case let .stepStarted(name, completedSteps, totalSteps):
            return "mutation.event.stepStarted:\(name):\(completedSteps)/\(totalSteps)"
        case let .stepSucceeded(name, completedSteps, totalSteps):
            return "mutation.event.stepSucceeded:\(name):\(completedSteps)/\(totalSteps)"
        }
    }

    func makeHarness() -> Harness {
        let traceRecorder = LockedTraceRecorder()
        let sinkRecorder = MHLogSinkRecorder()
        let logStore = makeLogStore(sinkRecorder: sinkRecorder)
        let logger = makeLogger(logStore: logStore)
        let notificationDestination = MHDeepLinkURLRecorder()
        let intentSource = MHDeepLinkURLRecorder()
        let routePipeline = makeRoutePipeline(
            logger: logger,
            traceRecorder: traceRecorder,
            mutationAttemptCounter: LockedCounter(),
            intentSource: intentSource,
            notificationDestination: notificationDestination
        )
        let runtime = makeRuntime(traceRecorder: traceRecorder)
        let lifecycle = makeLifecycle(
            runtime: runtime,
            routePipeline: routePipeline,
            traceRecorder: traceRecorder,
            notificationDestination: notificationDestination
        )

        return .init(
            runtime: runtime,
            lifecycle: lifecycle,
            traceRecorder: traceRecorder,
            sinkRecorder: sinkRecorder,
            logStore: logStore,
            notificationDestination: notificationDestination,
            intentSource: intentSource
        )
    }

    func makeLogStore(
        sinkRecorder: MHLogSinkRecorder
    ) -> MHLogStore {
        .init(
            policy: .init(
                minimumLevel: .debug,
                persistsToDisk: false,
                maximumInMemoryEvents: TestConstants.maximumInMemoryEvents,
                maximumDiskBytes: TestConstants.maximumDiskBytes
            ),
            sinks: [sinkRecorder]
        )
    }

    func makeLogger(
        logStore: MHLogStore
    ) -> MHLogger {
        .init(
            "MHPlatformIntegrationTests.swift",
            store: logStore,
            subsystem: "tests.integration"
        )
    }

    func makeRuntime(
        traceRecorder: LockedTraceRecorder
    ) -> MHAppRuntime {
        .init(
            configuration: .init(
                subscriptionProductIDs: ["premium.monthly"]
            ),
            preferenceStore: .init(),
            startStore: { _ in
                traceRecorder.record("runtime.startStore")
            },
            subscriptionSectionViewBuilder: {
                AnyView(EmptyView())
            },
            startAds: nil,
            nativeAdViewBuilder: nil
        )
    }

    func makeLifecycle(
        runtime: MHAppRuntime,
        routePipeline: MHAppRoutePipeline<IntegrationRoute>,
        traceRecorder: LockedTraceRecorder,
        notificationDestination: MHDeepLinkURLRecorder
    ) -> MHAppRuntimeLifecycle {
        .init(
            runtime: runtime,
            plan: .init(
                startupTasks: [
                    .init(name: "deliverNotificationRoute") {
                        await deliverNotificationRoute(
                            to: notificationDestination,
                            traceRecorder: traceRecorder
                        )
                    }
                ],
                activeTasks: [
                    .init(name: "synchronizePendingRoutes") {
                        await synchronizePendingRoutes(
                            routePipeline: routePipeline,
                            traceRecorder: traceRecorder,
                        )
                    }
                ]
            )
        )
    }

    func deliverNotificationRoute(
        to destination: MHDeepLinkURLRecorder,
        traceRecorder: LockedTraceRecorder
    ) async {
        let outcome = await MHNotificationOrchestrator.deliverRouteURL(
            payload: makePayload(),
            response: .init(
                actionIdentifier: "com.apple.UNNotificationDefaultActionIdentifier"
            ),
            destination: destination
        )

        traceRecorder.record(
            "startup.notification.\(Self.describe(outcome.source))"
        )
    }

    func makeRoutePipeline(
        logger: MHLogger,
        traceRecorder: LockedTraceRecorder,
        mutationAttemptCounter: LockedCounter,
        intentSource: MHDeepLinkURLRecorder,
        notificationDestination: MHDeepLinkURLRecorder
    ) -> MHAppRoutePipeline<IntegrationRoute> {
        .init(
            routeLifecycle: .init(
                logger: logger,
                initialReadiness: false,
                isDuplicate: ==
            ),
            using: Self.codec,
            pendingSources: [
                intentSource,
                notificationDestination
            ]
        ) { route in
                try await applyRoute(
                    route,
                    traceRecorder: traceRecorder,
                    mutationAttemptCounter: mutationAttemptCounter
                )
        }
    }

    func synchronizePendingRoutes(
        routePipeline: MHAppRoutePipeline<IntegrationRoute>,
        traceRecorder: LockedTraceRecorder
    ) async {
        let outcome = await routePipeline.synchronizePendingRoutesIfPossible()
        recordRouteOutcome(
            outcome,
            traceRecorder: traceRecorder
        )
    }

    func applyRoute(
        _ route: IntegrationRoute,
        traceRecorder: LockedTraceRecorder,
        mutationAttemptCounter: LockedCounter
    ) async throws {
        traceRecorder.record("route.apply:\(route.identifier)")

        let result = try await runMutationWorkflow(
            for: route,
            traceRecorder: traceRecorder,
            mutationAttemptCounter: mutationAttemptCounter
        )
        traceRecorder.record("mutation.result:\(result)")
    }

    func runMutationWorkflow(
        for route: IntegrationRoute,
        traceRecorder: LockedTraceRecorder,
        mutationAttemptCounter: LockedCounter
    ) async throws -> String {
        let adapter = makeMutationAdapter(traceRecorder: traceRecorder)

        return try await MHMutationWorkflow.runThrowing(
            name: "syncRoute",
            operation: {
                let attempt = mutationAttemptCounter.increment()

                if attempt == TestConstants.firstAttempt {
                    throw IntegrationError.temporaryFailure
                }

                return .init(
                    adapterValue: route.identifier,
                    resultValue: "synced:\(route.identifier)"
                )
            },
            adapter: adapter,
            onEvent: { event in
                traceRecorder.record(Self.describe(event))
            },
            configuration: .init(
                retryPolicy: .init(
                    maximumAttempts: TestConstants.maximumAttempts,
                    backoff: .immediate
                )
            )
        )
    }

    func makeMutationAdapter(
        traceRecorder: LockedTraceRecorder
    ) -> MHMutationAdapter<Int> {
        .init { identifier in
            [
                .init(name: "recordMutationStep") {
                    traceRecorder.record("mutation.step:\(identifier)")
                }
            ]
        }
    }

    func recordRouteOutcome(
        _ outcome: MHRouteExecutionOutcome<IntegrationRoute>?,
        traceRecorder: LockedTraceRecorder
    ) {
        switch outcome {
        case .some(.applied(let route)):
            traceRecorder.record("route.outcome:\(route.identifier)")
        case .some(.queued):
            Issue.record("Expected applied route outcome, got queued.")
        case .some(.deduplicated):
            Issue.record("Expected applied route outcome, got deduplicated.")
        case .none:
            Issue.record("Expected a pending route to be delivered.")
        }
    }

    func assertExpectedState(
        for harness: Harness
    ) async {
        #expect(harness.runtime.hasStarted)
        #expect(await harness.intentSource.consumeCountValue() == 1)
        #expect(await harness.notificationDestination.consumeCountValue() == 1)
        #expect(await harness.notificationDestination.latestURL() == nil)

        #expect(harness.traceRecorder.values() == [
            "runtime.startStore",
            "startup.notification.payload",
            "route.apply:7",
            "mutation.event.started:syncRoute:1",
            "mutation.event.failed:1:true",
            "mutation.event.retryScheduled:2",
            "mutation.event.started:syncRoute:2",
            "mutation.event.stepStarted:recordMutationStep:0/1",
            "mutation.step:7",
            "mutation.event.stepSucceeded:recordMutationStep:1/1",
            "mutation.event.succeeded:synced:7:2",
            "mutation.result:synced:7",
            "route.outcome:7"
        ])
        #expect(await harness.sinkRecorder.events().map(\.message) == [
            "accepted deep-link URL for route handling",
            "route applied"
        ])
        #expect(await harness.logStore.events().map(\.message) == [
            "accepted deep-link URL for route handling",
            "route applied"
        ])
    }

    func makePayload() -> MHNotificationPayload {
        .init(
            routes: .init(
                defaultRouteURL: Self.codec.preferredURL(
                    for: .item(TestConstants.routeIdentifier)
                )
            )
        )
    }
}
