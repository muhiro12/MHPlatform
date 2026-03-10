import MHAppRuntimeAds
import MHAppRuntimeDefaults
import MHAppRuntimeLicenses

public extension MHAppRuntime {
    /// Creates a runtime with the default StoreKit, ads, and license adapters.
    convenience init(
        configuration: MHAppConfiguration
    ) {
        let defaultsBundle = MHAppRuntimeDefaultsBundle(
            configuration: configuration
        )
        let adsBundle = MHAppRuntimeAdsBundle(
            configuration: configuration
        )
        let licensesBundle = MHAppRuntimeLicensesBundle(
            configuration: configuration
        )

        self.init(
            configuration: configuration,
            preferenceStore: defaultsBundle.preferenceStore,
            startStore: defaultsBundle.startStore,
            subscriptionSectionViewBuilder: defaultsBundle.subscriptionSectionViewBuilder,
            startAds: adsBundle.startAds,
            nativeAdViewBuilder: adsBundle.nativeAdViewBuilder,
            licensesViewBuilder: licensesBundle.licensesViewBuilder
        )
    }
}
