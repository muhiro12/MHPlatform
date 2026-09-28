/// App-specific identifiers and options for bootstrapping `MHAppRuntime`.
public struct MHAppConfiguration: Sendable, Hashable {
    /// Product identifiers used to determine premium subscription state.
    public let subscriptionProductIDs: [String]

    /// Optional StoreKit subscription group identifier for paywall presentation.
    public let subscriptionGroupID: String?

    /// Optional ad unit identifier for native ad loading.
    public let nativeAdUnitID: String?

    /// Controls whether the runtime exposes license screens.
    public let showsLicenses: Bool

    /// Opts into consent-managed ads when set. `nil` keeps ads independent of consent.
    public let adsConsent: MHAdsConsentConfiguration?

    /// Creates a runtime configuration.
    public init(
        subscriptionProductIDs: [String] = [],
        subscriptionGroupID: String? = nil,
        nativeAdUnitID: String? = nil,
        showsLicenses: Bool = true,
        adsConsent: MHAdsConsentConfiguration? = nil
    ) {
        self.subscriptionProductIDs = subscriptionProductIDs
        self.subscriptionGroupID = subscriptionGroupID
        self.nativeAdUnitID = nativeAdUnitID
        self.showsLicenses = showsLicenses
        self.adsConsent = adsConsent
    }
}
