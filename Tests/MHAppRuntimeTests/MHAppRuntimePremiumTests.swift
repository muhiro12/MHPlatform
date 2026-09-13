import MHAppRuntime
import SwiftUI
import Testing

struct MHAppRuntimePremiumTests {
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
}
