/// App-specific identifiers and options for bootstrapping `MHAppRuntime`.
public struct MHAppConfiguration: Sendable, Hashable {
    /// Product identifiers used to determine premium subscription state.
    public let subscriptionProductIDs: [String]

    /// Optional StoreKit subscription group identifier for paywall presentation.
    public let subscriptionGroupID: String?

    /// Optional ad unit identifier for native ad loading.
    public let nativeAdUnitID: String?

    /// Optional `UserDefaults` suite name for shared preference storage.
    public let preferencesSuiteName: String?

    /// Controls whether the runtime exposes license screens.
    public let showsLicenses: Bool

    /// Creates a runtime configuration.
    public init(
        subscriptionProductIDs: [String] = [],
        subscriptionGroupID: String? = nil,
        nativeAdUnitID: String? = nil,
        preferencesSuiteName: String? = nil,
        showsLicenses: Bool = true
    ) {
        self.subscriptionProductIDs = subscriptionProductIDs
        self.subscriptionGroupID = subscriptionGroupID
        self.nativeAdUnitID = nativeAdUnitID
        self.preferencesSuiteName = preferencesSuiteName
        self.showsLicenses = showsLicenses
    }
}
