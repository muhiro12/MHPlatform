import MHAppRuntime
import SwiftUI
import Testing

struct MHAppRuntimePremiumTests {
    @MainActor
    @Test
    func existing_entitlement_resolves_active_during_startup_without_building_purchase_ui() {
        let runtime = makeRuntime { report in
            report(["premium.monthly"])
        }

        #expect(runtime.premiumStatus == .unknown)
        runtime.startIfNeeded()
        #expect(runtime.premiumStatus == .active)
    }

    @MainActor
    @Test
    func entitlement_updates_continue_after_startup_without_reopening_store() throws {
        var report: (@MainActor (Set<String>) -> Void)?
        var startCount = 0
        let runtime = makeRuntime { callback in
            startCount += 1
            report = callback
            callback([])
        }
        runtime.startIfNeeded()
        #expect(runtime.premiumStatus == .inactive)

        let reportSnapshot = try #require(report)
        reportSnapshot(["premium.monthly"])
        #expect(runtime.premiumStatus == .active)
        reportSnapshot(["premium.yearly", "other.product"])
        #expect(runtime.premiumStatus == .active)
        runtime.startIfNeeded()
        #expect(runtime.premiumStatus == .active)
        reportSnapshot(["other.product"])
        #expect(runtime.premiumStatus == .inactive)
        #expect(startCount == 1)
    }

    @MainActor
    @Test
    func retained_callback_does_not_retain_runtime_or_update_its_replacement() throws {
        var previousReport: (@MainActor (Set<String>) -> Void)?
        var previousRuntime: MHAppRuntime? = makeRuntime { report in
            previousReport = report
        }
        let previousRuntimeIfAlive = { [weak previousRuntime] in
            previousRuntime
        }
        previousRuntime?.startIfNeeded()
        let reportPreviousSnapshot = try #require(previousReport)
        reportPreviousSnapshot(["premium.monthly"])

        let replacementRuntime = makeRuntime { report in
            report(["premium.yearly"])
        }
        replacementRuntime.startIfNeeded()
        reportPreviousSnapshot([])
        #expect(previousRuntime?.premiumStatus == .inactive)
        #expect(replacementRuntime.premiumStatus == .active)

        previousRuntime = nil
        #expect(previousRuntimeIfAlive() == nil)
        reportPreviousSnapshot([])
        #expect(replacementRuntime.premiumStatus == .active)
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
            subscriptionSectionFactory: .init {
                EmptyView()
            },
            startAds: {
                // no-op
            },
            nativeAdFactory: .init { _ in
                EmptyView()
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

        purchasedProductIDsDidSet?([])
        #expect(runtime.premiumStatus == .inactive)
        #expect(runtime.adsAvailability == .available)
    }

    @MainActor
    @Test
    func native_ad_view_forwards_layouts_only_while_ads_are_available() {
        var purchasedProductIDsDidSet: (@MainActor (Set<String>) -> Void)?
        var requestedLayouts = [MHNativeAdLayout]()
        let runtime = MHAppRuntime(
            configuration: .init(
                subscriptionProductIDs: ["premium.monthly"],
                nativeAdUnitID: "ad-unit"
            ),
            preferenceStore: .init(),
            startStore: { purchasedProductIDsDidSet = $0 },
            subscriptionSectionFactory: .init {
                EmptyView()
            },
            startAds: nil,
            nativeAdFactory: .init { layout in
                requestedLayouts.append(layout)
                return EmptyView()
            }
        )
        runtime.startIfNeeded()

        _ = runtime.nativeAdView(layout: .compact)
        _ = runtime.nativeAdView(layout: .media)
        #expect(requestedLayouts == [.compact, .media])

        purchasedProductIDsDidSet?(["premium.monthly"])
        _ = runtime.nativeAdView(layout: .compact)
        #expect(requestedLayouts == [.compact, .media])

        purchasedProductIDsDidSet?([])
        _ = runtime.nativeAdView(layout: .media)
        #expect(requestedLayouts == [.compact, .media, .media])
    }
}

@MainActor
private extension MHAppRuntimePremiumTests {
    func makeRuntime(startStore: @escaping MHAppRuntime.StartStore) -> MHAppRuntime {
        .init(
            configuration: .init(
                subscriptionProductIDs: [" premium.monthly ", "premium.yearly"]
            ),
            preferenceStore: .init(),
            startStore: startStore,
            subscriptionSectionFactory: .init {
                Issue.record("Entitlement propagation must not require constructing the purchase UI.")
                return EmptyView()
            },
            startAds: nil,
            nativeAdFactory: nil
        )
    }
}
