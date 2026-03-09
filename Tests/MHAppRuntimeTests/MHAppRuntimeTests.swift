import Foundation
import MHAppRuntime
@testable import MHAppRuntimeCore
import MHPreferences
import SwiftUI
import Testing

struct MHAppRuntimeTests {
    @MainActor
    @Test
    func startIfNeeded_runs_startup_side_effects_once() {
        var storeStartCount = 0
        var adsStartCount = 0

        let runtime = MHAppRuntime(
            configuration: .init(
                subscriptionProductIDs: ["premium.monthly"],
                nativeAdUnitID: "ad-unit"
            ),
            preferenceStore: .init(),
            startStore: { _ in
                storeStartCount += 1
            },
            subscriptionSectionViewBuilder: {
                AnyView(EmptyView())
            },
            startAds: {
                adsStartCount += 1
            },
            nativeAdViewBuilder: { _ in
                AnyView(EmptyView())
            }
        )

        runtime.startIfNeeded()
        runtime.startIfNeeded()
        runtime.start()

        #expect(runtime.hasStarted)
        #expect(storeStartCount == 1)
        #expect(adsStartCount == 1)
    }

    @MainActor
    @Test
    func premium_status_and_ads_availability_follow_purchase_updates() {
        var purchasedProductIDsDidSet: (@MainActor (Set<String>) -> Void)?

        let runtime = MHAppRuntime(
            configuration: .init(
                subscriptionProductIDs: ["premium.monthly"],
                nativeAdUnitID: "ad-unit"
            ),
            preferenceStore: .init(),
            startStore: { purchasedProductIDsDidSet = $0 },
            subscriptionSectionViewBuilder: {
                AnyView(EmptyView())
            },
            startAds: {
                // no-op
            },
            nativeAdViewBuilder: { _ in
                AnyView(EmptyView())
            }
        )

        runtime.startIfNeeded()

        #expect(runtime.premiumStatus == .unknown)
        #expect(runtime.adsAvailability == .available)

        purchasedProductIDsDidSet?(["other.product"])
        #expect(runtime.premiumStatus == .inactive)
        #expect(runtime.adsAvailability == .available)

        purchasedProductIDsDidSet?(["premium.monthly"])
        #expect(runtime.premiumStatus == .active)
        #expect(runtime.adsAvailability == .disabledByPremium)
    }

    @MainActor
    @Test
    func ads_availability_is_not_configured_without_ad_unit() {
        let runtime = MHAppRuntime(
            configuration: .init(
                subscriptionProductIDs: ["premium.monthly"]
            ),
            preferenceStore: .init(),
            startStore: { _ in
                // no-op
            },
            subscriptionSectionViewBuilder: {
                AnyView(EmptyView())
            },
            startAds: nil,
            nativeAdViewBuilder: nil
        )

        runtime.startIfNeeded()

        #expect(runtime.adsAvailability == .notConfigured)
    }

    @MainActor
    @Test
    func preference_store_uses_configured_suite_name() {
        let suiteName = "MHAppRuntimeTests.PreferenceStore.\(UUID().uuidString)"
        let key = MHBoolPreferenceKey(
            namespace: "mhplatform.runtime.tests",
            name: "suite",
            default: false
        )
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create UserDefaults suite for tests.")
            return
        }

        userDefaults.removePersistentDomain(forName: suiteName)
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let runtime = MHAppRuntime(
            configuration: .init(preferencesSuiteName: suiteName)
        )
        runtime.preferenceStore.set(true, for: key)

        #expect(userDefaults.bool(forKey: key.storageKey))
    }

    @MainActor
    @Test
    func lifecycle_runs_startup_then_active_tasks_in_order() async {
        var events = [String]()

        let runtime = makeRuntime { _ in
            events.append("startStore")
        }
        let lifecycle = MHAppRuntimeLifecycle(
            runtime: runtime,
            plan: .init(
                startupTasks: [
                    .init(name: "loadConfig") {
                        events.append("startup.loadConfig")
                    },
                    .init(name: "refreshNotifications") {
                        events.append("startup.refreshNotifications")
                    }
                ],
                activeTasks: [
                    .init(name: "review") {
                        events.append("active.review")
                    },
                    .init(name: "deepLink") {
                        events.append("active.deepLink")
                    }
                ]
            )
        )

        await lifecycle.handleInitialAppearance()
        await lifecycle.handleScenePhase(.background)
        await lifecycle.handleScenePhase(.active)

        #expect(
            events == [
                "startStore",
                "startup.loadConfig",
                "startup.refreshNotifications",
                "active.review",
                "active.deepLink"
            ]
        )
    }

    @MainActor
    @Test
    func lifecycle_skips_first_active_phase_when_requested() async {
        var events = [String]()

        let runtime = makeRuntime { _ in
            events.append("startStore")
        }
        let lifecycle = MHAppRuntimeLifecycle(
            runtime: runtime,
            plan: .init(
                activeTasks: [
                    .init(name: "sync") {
                        events.append("active.sync")
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
                "active.sync"
            ]
        )
    }

    @MainActor
    @Test
    func lifecycle_initial_appearance_is_idempotent_even_after_active_phase() async {
        var events = [String]()

        let runtime = makeRuntime { _ in
            events.append("startStore")
        }
        let lifecycle = MHAppRuntimeLifecycle(
            runtime: runtime,
            plan: .init(
                startupTasks: [
                    .init(name: "bootstrap") {
                        events.append("startup.bootstrap")
                    }
                ],
                activeTasks: [
                    .init(name: "refresh") {
                        events.append("active.refresh")
                    }
                ]
            )
        )

        await lifecycle.handleScenePhase(.active)
        await lifecycle.handleInitialAppearance()
        await lifecycle.handleInitialAppearance()

        #expect(
            events == [
                "startStore",
                "active.refresh",
                "startup.bootstrap"
            ]
        )
        #expect(runtime.hasStarted)
    }

    @MainActor
    @Test
    func lifecycle_modifier_builds_without_eagerly_starting_runtime() {
        let runtime = makeRuntime()

        let view = EmptyView().mhAppRuntimeLifecycle(
            runtime: runtime,
            plan: .init(
                startupTasks: [
                    .init(name: "bootstrap") {
                        // no-op
                    }
                ]
            )
        )

        #expect(String(describing: type(of: view)).contains("ModifiedContent"))
        #expect(runtime.hasStarted == false)
    }

    @MainActor
    @Test
    func runtime_environment_modifier_builds_without_eagerly_starting_runtime() {
        let runtime = makeRuntime()

        let runtimeView = EmptyView().mhAppRuntimeEnvironment(runtime)
        let bootstrapView = EmptyView().mhAppRuntimeEnvironment(
            MHAppRuntimeBootstrap(
                runtime: runtime,
                lifecyclePlan: .empty
            )
        )

        #expect(String(describing: type(of: runtimeView)).contains("ModifiedContent"))
        #expect(String(describing: type(of: bootstrapView)).contains("ModifiedContent"))
        #expect(runtime.hasStarted == false)
    }
}

@MainActor
private extension MHAppRuntimeTests {
    func makeRuntime(
        startStore: @escaping (@MainActor (Set<String>) -> Void) -> Void = { _ in
            // no-op
        }
    ) -> MHAppRuntime {
        MHAppRuntime(
            configuration: .init(
                subscriptionProductIDs: ["premium.monthly"],
                nativeAdUnitID: "ad-unit"
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
}
