import MHAppRuntime
import SwiftUI
import Testing

extension MHAppRuntimeAdsConsentTests {
    @MainActor
    @Test
    func updated_eligibility_is_visible_before_form_finishes() async {
        let consent = FakeAdsConsent(snapshotAfterForm: .denied)
        var startAdsCount = 0
        let runtime = makeRuntime(
            consent: consent,
            startAds: { startAdsCount += 1 },
            purchasedProductIDsDidSet: { $0([]) }
        )
        consent.onUpdate = {
            consent.current = .allowed
        }
        consent.onForm = {
            #expect(runtime.canDisplayAds)
            #expect(runtime.adsPrivacyOptionsRequirement == .required)
            #expect(startAdsCount == 1)
        }

        runtime.startIfNeeded()
        await settle()

        #expect(runtime.canDisplayAds == false)
        #expect(startAdsCount == 1)
    }

    @MainActor
    @Test
    func premium_activated_during_update_skips_form_and_retries_after_expiry() async {
        let consent = FakeAdsConsent(snapshotAfterForm: .allowed)
        var purchasedProductIDsDidSet: (@MainActor (Set<String>) -> Void)?
        var startAdsCount = 0
        let runtime = makeRuntime(
            consent: consent,
            startAds: { startAdsCount += 1 },
            purchasedProductIDsDidSet: { purchasedProductIDsDidSet = $0 }
        )
        consent.onUpdate = {
            purchasedProductIDsDidSet?(["premium.monthly"])
        }

        runtime.startIfNeeded()
        purchasedProductIDsDidSet?([])
        await settle()

        #expect(runtime.premiumStatus == .active)
        #expect(consent.formCount == .zero)
        #expect(startAdsCount == .zero)

        consent.onUpdate = { () }
        purchasedProductIDsDidSet?([])
        await settle()

        #expect(consent.updateCount == 2)
        #expect(consent.formCount == 1)
        #expect(startAdsCount == 1)
    }

    @MainActor
    @Test
    func cancelled_update_does_not_present_form_or_start_ads_and_can_retry() async {
        let consent = FakeAdsConsent(snapshotAfterForm: .allowed)
        consent.updateError = .offline
        var startAdsCount = 0
        let runtime = makeRuntime(
            consent: consent,
            startAds: { startAdsCount += 1 },
            purchasedProductIDsDidSet: { $0([]) }
        )
        runtime.startIfNeeded()
        await settle()
        consent.updateError = nil
        consent.onUpdate = {
            consent.current = .allowed
            withUnsafeCurrentTask { task in
                task?.cancel()
            }
        }
        consent.current = .unknown

        await Task {
            await runtime.refreshAdsConsent()
        }.value

        #expect(consent.formCount == .zero)
        #expect(startAdsCount == .zero)

        consent.onUpdate = { () }
        await runtime.refreshAdsConsent()
        #expect(consent.formCount == 1)
        #expect(startAdsCount == 1)
    }

    @MainActor
    @Test
    func consent_bridge_is_ignored_when_ads_are_not_configured() async {
        let consent = FakeAdsConsent(snapshotAfterForm: .allowed)
        let runtime = MHAppRuntime(
            configuration: .init(),
            preferenceStore: .init(),
            startStore: { $0([]) },
            subscriptionSectionFactory: .init {
                EmptyView()
            },
            startAds: nil,
            nativeAdFactory: nil,
            adsConsent: consent.bridge
        )

        runtime.startIfNeeded()
        await settle()

        #expect(runtime.adsConsentStatus == .notManaged)
        #expect(runtime.adsAvailability == .notConfigured)
        #expect(runtime.canDisplayAds == false)
        #expect(consent.updateCount == .zero)
    }
}
