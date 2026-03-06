import Foundation
@testable import MHAppRuntime
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
}
