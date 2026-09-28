import MHAppRuntime
import SwiftUI
import Testing

struct MHAppRuntimeAdsConsentTests {
    @MainActor
    @Test
    func runtime_without_consent_bridge_starts_ads_immediately() {
        var startAdsCount = 0
        let runtime = makeRuntime(
            consent: nil,
            startAds: { startAdsCount += 1 },
            purchasedProductIDsDidSet: { _ in () }
        )

        runtime.startIfNeeded()

        #expect(runtime.adsConsentStatus == .notManaged)
        #expect(runtime.canDisplayAds)
        #expect(startAdsCount == 1)
    }

    @MainActor
    @Test
    func consent_waits_for_premium_resolution_before_any_request() async {
        let consent = FakeAdsConsent(snapshotAfterForm: .allowed)
        var startAdsCount = 0
        var purchasedProductIDsDidSet: (@MainActor (Set<String>) -> Void)?
        let runtime = makeRuntime(
            consent: consent,
            startAds: { startAdsCount += 1 },
            purchasedProductIDsDidSet: { purchasedProductIDsDidSet = $0 }
        )

        runtime.startIfNeeded()
        await settle()

        #expect(runtime.adsConsentStatus == .pending)
        #expect(runtime.canDisplayAds == false)
        #expect(consent.updateCount == .zero)
        #expect(startAdsCount == .zero)

        purchasedProductIDsDidSet?([])
        await settle()

        #expect(consent.updateCount == 1)
        #expect(consent.formCount == 1)
        #expect(runtime.adsConsentStatus == .canRequestAds)
        #expect(runtime.adsPrivacyOptionsRequirement == .required)
        #expect(runtime.canDisplayAds)
        #expect(startAdsCount == 1)
    }

    @MainActor
    @Test
    func premium_users_are_never_asked_for_consent() async {
        let consent = FakeAdsConsent(snapshotAfterForm: .allowed)
        var startAdsCount = 0
        var purchasedProductIDsDidSet: (@MainActor (Set<String>) -> Void)?
        let runtime = makeRuntime(
            consent: consent,
            startAds: { startAdsCount += 1 },
            purchasedProductIDsDidSet: { purchasedProductIDsDidSet = $0 }
        )

        runtime.startIfNeeded()
        purchasedProductIDsDidSet?(["premium.monthly"])
        await settle()

        #expect(runtime.adsAvailability == .disabledByPremium)
        #expect(runtime.adsConsentStatus == .pending)
        #expect(consent.updateCount == .zero)
        #expect(startAdsCount == .zero)
    }

    @MainActor
    @Test
    func denied_consent_keeps_ads_stopped_and_hides_native_ads() async {
        let consent = FakeAdsConsent(snapshotAfterForm: .denied)
        var startAdsCount = 0
        var requestedLayouts = [MHNativeAdLayout]()
        let runtime = makeRuntime(
            consent: consent,
            startAds: { startAdsCount += 1 },
            purchasedProductIDsDidSet: { $0([]) },
            onNativeAd: { requestedLayouts.append($0) }
        )

        runtime.startIfNeeded()
        await settle()
        _ = runtime.nativeAdView(layout: .compact)

        #expect(runtime.adsConsentStatus == .cannotRequestAds)
        #expect(runtime.adsAvailability == .available)
        #expect(runtime.canDisplayAds == false)
        #expect(requestedLayouts.isEmpty)
        #expect(startAdsCount == .zero)
    }

    @MainActor
    @Test
    func stored_consent_starts_ads_when_this_session_update_fails() async {
        let consent = FakeAdsConsent(snapshotAfterForm: .allowed)
        consent.current = .allowed
        consent.updateError = FakeAdsConsent.Failure.offline
        var startAdsCount = 0
        let runtime = makeRuntime(
            consent: consent,
            startAds: { startAdsCount += 1 },
            purchasedProductIDsDidSet: { $0([]) }
        )

        runtime.startIfNeeded()
        await settle()

        #expect(consent.formCount == .zero)
        #expect(runtime.adsConsentStatus == .canRequestAds)
        #expect(startAdsCount == 1)
    }

    @MainActor
    @Test
    func failed_first_evaluation_can_be_retried_explicitly() async {
        let consent = FakeAdsConsent(snapshotAfterForm: .allowed)
        consent.updateError = FakeAdsConsent.Failure.offline
        var startAdsCount = 0
        let runtime = makeRuntime(
            consent: consent,
            startAds: { startAdsCount += 1 },
            purchasedProductIDsDidSet: { $0([]) }
        )

        runtime.startIfNeeded()
        await settle()

        #expect(runtime.adsConsentStatus == .cannotRequestAds)
        #expect(startAdsCount == .zero)

        consent.updateError = nil
        await runtime.refreshAdsConsent()

        #expect(consent.updateCount == 2)
        #expect(runtime.adsConsentStatus == .canRequestAds)
        #expect(startAdsCount == 1)
    }

    @MainActor
    @Test
    func duplicate_premium_callbacks_evaluate_and_start_once() async {
        let consent = FakeAdsConsent(snapshotAfterForm: .allowed)
        var startAdsCount = 0
        var purchasedProductIDsDidSet: (@MainActor (Set<String>) -> Void)?
        let runtime = makeRuntime(
            consent: consent,
            startAds: { startAdsCount += 1 },
            purchasedProductIDsDidSet: { purchasedProductIDsDidSet = $0 }
        )

        runtime.startIfNeeded()
        purchasedProductIDsDidSet?([])
        purchasedProductIDsDidSet?([])
        await settle()
        purchasedProductIDsDidSet?(["other.product"])
        await settle()

        #expect(consent.updateCount == 1)
        #expect(startAdsCount == 1)
    }

    @MainActor
    @Test
    func ads_deferred_by_premium_start_after_premium_ends() async {
        let consent = FakeAdsConsent(snapshotAfterForm: .allowed)
        var startAdsCount = 0
        var purchasedProductIDsDidSet: (@MainActor (Set<String>) -> Void)?
        let runtime = makeRuntime(
            consent: consent,
            startAds: { startAdsCount += 1 },
            purchasedProductIDsDidSet: { purchasedProductIDsDidSet = $0 }
        )
        consent.onForm = {
            purchasedProductIDsDidSet?(["premium.monthly"])
        }

        runtime.startIfNeeded()
        purchasedProductIDsDidSet?([])
        await settle()

        #expect(runtime.adsConsentStatus == .canRequestAds)
        #expect(runtime.premiumStatus == .active)
        #expect(startAdsCount == .zero)

        purchasedProductIDsDidSet?([])
        await settle()

        #expect(startAdsCount == 1)
        #expect(consent.updateCount == 1)
    }

    @MainActor
    @Test
    func privacy_options_can_revoke_and_restore_eligibility() async throws {
        let consent = FakeAdsConsent(snapshotAfterForm: .allowed)
        var startAdsCount = 0
        let runtime = makeRuntime(
            consent: consent,
            startAds: { startAdsCount += 1 },
            purchasedProductIDsDidSet: { $0([]) }
        )

        runtime.startIfNeeded()
        await settle()
        #expect(runtime.canDisplayAds)

        consent.snapshotAfterPrivacyOptions = .denied
        try await runtime.presentAdsPrivacyOptions()
        #expect(runtime.adsConsentStatus == .cannotRequestAds)
        #expect(runtime.canDisplayAds == false)

        consent.snapshotAfterPrivacyOptions = .allowed
        try await runtime.presentAdsPrivacyOptions()
        #expect(runtime.canDisplayAds)
        #expect(consent.privacyOptionsCount == 2)
        #expect(startAdsCount == 1)
    }

    @MainActor
    @Test
    func privacy_options_failure_rereads_sdk_state_and_rethrows() async {
        let consent = FakeAdsConsent(snapshotAfterForm: .allowed)
        let runtime = makeRuntime(
            consent: consent,
            startAds: { () },
            purchasedProductIDsDidSet: { $0([]) }
        )
        runtime.startIfNeeded()
        await settle()

        consent.privacyOptionsError = FakeAdsConsent.Failure.offline
        consent.current = .denied

        await #expect(throws: FakeAdsConsent.Failure.offline) {
            try await runtime.presentAdsPrivacyOptions()
        }
        #expect(runtime.adsConsentStatus == .cannotRequestAds)
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

private extension MHAppRuntimeAdsConsentTests {
    static let settleYieldCount = 20

    @MainActor
    func makeRuntime(
        consent: FakeAdsConsent?,
        startAds: @escaping MHAppRuntime.StartAds,
        purchasedProductIDsDidSet: @escaping MHAppRuntime.StartStore,
        onNativeAd: @escaping @MainActor (MHNativeAdLayout) -> Void = { _ in () }
    ) -> MHAppRuntime {
        .init(
            configuration: .init(
                subscriptionProductIDs: ["premium.monthly"],
                nativeAdUnitID: "ad-unit"
            ),
            preferenceStore: .init(),
            startStore: purchasedProductIDsDidSet,
            subscriptionSectionFactory: .init {
                EmptyView()
            },
            startAds: startAds,
            nativeAdFactory: .init { layout in
                onNativeAd(layout)
                return EmptyView()
            },
            adsConsent: consent?.bridge
        )
    }

    /// Lets main-actor tasks started by the runtime finish.
    @MainActor
    func settle() async {
        for _ in 0..<Self.settleYieldCount {
            await Task.yield()
        }
    }
}
