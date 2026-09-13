import Foundation
import MHAppRuntime
import MHAppRuntimeAds
import MHAppRuntimeDefaults
import MHAppRuntimeLicenses
import MHPreferences
import Testing

struct MHAppRuntimeBundleTests {
    @MainActor
    @Test
    func defaults_bundle_uses_descriptor_default_selection() {
        let suiteName = "MHAppRuntimeTests.DefaultsBundle.\(UUID().uuidString)"
        let descriptor = MHBoolPreferenceDescriptor(
            storageKey: "mhplatform.runtime.tests.defaultsBundle",
            defaultSelection: .suite(suiteName),
            default: false
        )
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create UserDefaults suite for defaults bundle tests.")
            return
        }

        userDefaults.removePersistentDomain(forName: suiteName)
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let bundle = MHAppRuntimeDefaultsBundle(
            configuration: .init()
        )
        bundle.preferenceStore.set(true, for: descriptor)

        #expect(userDefaults.bool(forKey: descriptor.storageKey))
    }

    @MainActor
    @Test(arguments: [nil, "", " \n\t"] as [String?])
    func ads_bundle_disables_ads_without_ad_unit(adUnitID: String?) {
        let bundle = MHAppRuntimeAdsBundle(
            configuration: .init(
                subscriptionProductIDs: ["premium.monthly"],
                nativeAdUnitID: adUnitID
            )
        )

        #expect(bundle.startAds == nil)
        #expect(bundle.nativeAdFactory == nil)
    }

    @MainActor
    @Test(arguments: ["ad-unit", "  ad-unit\n"])
    func ads_bundle_provides_both_bridges_on_supported_platforms(adUnitID: String) {
        let bundle = MHAppRuntimeAdsBundle(
            configuration: .init(nativeAdUnitID: adUnitID)
        )

        #if canImport(GoogleMobileAdsWrapper)
        #expect(bundle.startAds != nil)
        #expect(bundle.nativeAdFactory != nil)
        #else
        #expect(bundle.startAds == nil)
        #expect(bundle.nativeAdFactory == nil)
        #endif
    }

    @MainActor
    @Test
    func split_bundles_compose_runtime_initializer() {
        let configuration = MHAppConfiguration(
            subscriptionProductIDs: ["premium.monthly"],
            showsLicenses: false
        )
        let defaultsBundle = MHAppRuntimeDefaultsBundle(
            configuration: configuration
        )
        let adsBundle = MHAppRuntimeAdsBundle(
            configuration: configuration
        )
        let licensesBundle = MHAppRuntimeLicensesBundle(
            configuration: configuration
        )

        let runtime = MHAppRuntime(
            configuration: configuration,
            preferenceStore: defaultsBundle.preferenceStore,
            startStore: defaultsBundle.startStore,
            subscriptionSectionFactory: defaultsBundle.subscriptionSectionFactory,
            startAds: adsBundle.startAds,
            nativeAdFactory: adsBundle.nativeAdFactory,
            licensesFactory: licensesBundle.licensesFactory
        )

        #expect(runtime.configuration == configuration)
        #expect(runtime.adsAvailability == .notConfigured)
    }
}
