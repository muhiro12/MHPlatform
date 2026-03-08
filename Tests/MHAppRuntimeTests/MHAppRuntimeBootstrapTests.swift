import Foundation
@testable import MHAppRuntime
import MHLogging
import MHPlatformTesting
import MHRouteExecution
import SwiftUI
import Testing

struct MHAppRuntimeBootstrapTests {
    @MainActor
    @Test
    func configuration_init_keeps_runtime_and_plan() {
        let configuration = MHAppConfiguration(
            subscriptionProductIDs: ["premium.monthly"],
            subscriptionGroupID: "group.example",
            nativeAdUnitID: "ad-unit",
            preferencesSuiteName: "MHPlatform.Bootstrap.Tests",
            showsLicenses: false
        )
        let lifecyclePlan = MHAppRuntimeLifecyclePlan(
            startupTasks: [
                .init(name: "startup") {
                    // no-op
                }
            ],
            activeTasks: [
                .init(name: "active") {
                    // no-op
                }
            ],
            skipFirstActivePhase: true
        )

        let bootstrap = MHAppRuntimeBootstrap(
            configuration: configuration,
            lifecyclePlan: lifecyclePlan
        )

        #expect(bootstrap.runtime.configuration == configuration)
        #expect(bootstrap.lifecyclePlan == lifecyclePlan)
        #expect(bootstrap.routeInbox == nil)
    }

    @MainActor
    @Test
    func route_pipeline_init_exposes_shared_inbox_and_makeLifecycle_runs_plan() async throws {
        var events = [String]()
        let runtime = makeRuntime { _ in
            events.append("runtime.startStore")
        }
        let routePipeline = makeRoutePipeline()
        let lifecyclePlan = MHAppRuntimeLifecyclePlan(
            startupTasks: [
                .init(name: "startup.bootstrap") {
                    events.append("startup.bootstrap")
                }
            ],
            activeTasks: [
                .init(name: "active.refresh") {
                    events.append("active.refresh")
                }
            ]
        )
        let bootstrap = MHAppRuntimeBootstrap(
            runtime: runtime,
            lifecyclePlan: lifecyclePlan,
            routePipeline: routePipeline
        )

        let routeInbox = try #require(bootstrap.routeInbox)
        #expect(routeInbox === routePipeline.inbox)

        let lifecycle = bootstrap.makeLifecycle()
        await lifecycle.handleInitialAppearance()
        await lifecycle.handleScenePhase(.active)

        #expect(events == [
            "runtime.startStore",
            "startup.bootstrap",
            "active.refresh"
        ])
    }

    @MainActor
    @Test
    func route_pipeline_task_synchronizes_once_per_run() async {
        let routeRecorder = MHRouteExecutionRecorder<String>()
        let firstSource = MHDeepLinkURLRecorder(
            initialURL: URL(string: "test://route/12")
        )
        let secondSource = MHDeepLinkURLRecorder(
            initialURL: URL(string: "test://route/34")
        )
        let routeLifecycle = MHRouteLifecycle<Int>(
            logger: makeLogger(),
            initialReadiness: false,
            isDuplicate: ==
        )
        let routePipeline = MHAppRoutePipeline(
            routeLifecycle: routeLifecycle,
            parse: Self.parseRoute(from:),
            pendingSources: [
                firstSource,
                secondSource
            ]
        ) { resolvedRoute in
            await routeRecorder.record("apply:\(resolvedRoute)")
        }
        let task = routePipeline.task(name: "drainPendingRoutes")

        await task.run()

        #expect(await firstSource.consumeCountValue() == 1)
        #expect(await secondSource.consumeCountValue() == 0)
        #expect(await routeRecorder.values() == ["apply:12"])

        await task.run()

        #expect(await secondSource.consumeCountValue() == 1)
        #expect(await routeRecorder.values() == [
            "apply:12",
            "apply:34"
        ])
    }

    @MainActor
    @Test
    func bootstrap_without_route_pipeline_makes_lifecycle() async {
        var events = [String]()
        let runtime = makeRuntime { _ in
            events.append("runtime.startStore")
        }
        let bootstrap = MHAppRuntimeBootstrap(
            runtime: runtime,
            lifecyclePlan: .init(
                startupTasks: [
                    .init(name: "startup.loadConfig") {
                        events.append("startup.loadConfig")
                    }
                ],
                activeTasks: [
                    .init(name: "active.refresh") {
                        events.append("active.refresh")
                    }
                ]
            )
        )

        let lifecycle = bootstrap.makeLifecycle()
        await lifecycle.handleInitialAppearance()
        await lifecycle.handleScenePhase(.active)

        #expect(bootstrap.routeInbox == nil)
        #expect(events == [
            "runtime.startStore",
            "startup.loadConfig",
            "active.refresh"
        ])
    }

    @MainActor
    @Test
    func bootstrap_modifier_builds_without_eagerly_starting_runtime() {
        let runtime = makeRuntime()
        let bootstrap = MHAppRuntimeBootstrap(
            runtime: runtime,
            lifecyclePlan: .init(
                startupTasks: [
                    .init(name: "bootstrap") {
                        // no-op
                    }
                ]
            )
        )

        let view = EmptyView().mhAppRuntimeBootstrap(bootstrap)

        #expect(String(describing: type(of: view)).contains("ModifiedContent"))
        #expect(runtime.hasStarted == false)
    }
}

@MainActor
private extension MHAppRuntimeBootstrapTests {
    enum TestConstants {
        static let maximumInMemoryEvents = 20
        static let maximumDiskBytes = 1_000
    }

    nonisolated static func parseRoute(from url: URL) -> Int? {
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
            "Tests/MHAppRuntimeTests/MHAppRuntimeBootstrapTests.swift",
            store: store,
            subsystem: "tests.runtime.bootstrap"
        )
    }

    func makeRuntime(
        startStore: @escaping MHAppRuntime.StartStore = { _ in
            // no-op
        }
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

    func makeRoutePipeline() -> MHAppRoutePipeline<Int> {
        .init(
            routeLifecycle: .init(
                logger: makeLogger(),
                initialReadiness: false,
                isDuplicate: ==
            ),
            parse: Self.parseRoute(from:)
        ) { _ in
            // no-op
        }
    }
}
