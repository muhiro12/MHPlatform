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
    func defaults_bundle_uses_configured_suite_name() {
        let suiteName = "MHAppRuntimeTests.DefaultsBundle.\(UUID().uuidString)"
        let key = MHBoolPreferenceKey(
            namespace: "mhplatform.runtime.tests",
            name: "defaultsBundle",
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
            configuration: .init(preferencesSuiteName: suiteName)
        )
        bundle.preferenceStore.set(true, for: key)

        #expect(userDefaults.bool(forKey: key.storageKey))
    }

    @MainActor
    @Test
    func ads_bundle_disables_ads_without_ad_unit() {
        let bundle = MHAppRuntimeAdsBundle(
            configuration: .init(
                subscriptionProductIDs: ["premium.monthly"]
            )
        )

        #expect(bundle.startAds == nil)
        #expect(bundle.nativeAdViewBuilder == nil)
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
            subscriptionSectionViewBuilder: defaultsBundle.subscriptionSectionViewBuilder,
            startAds: adsBundle.startAds,
            nativeAdViewBuilder: adsBundle.nativeAdViewBuilder,
            licensesViewBuilder: licensesBundle.licensesViewBuilder
        )

        #expect(runtime.configuration == configuration)
        #expect(runtime.adsAvailability == .notConfigured)
    }
}
