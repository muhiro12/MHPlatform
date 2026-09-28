/// Consent state read from the consent SDK after an operation.
public struct MHAdsConsentSnapshot: Sendable, Hashable {
    /// Whether the consent SDK allows ad requests now.
    public let canRequestAds: Bool

    /// Whether the app must offer a privacy options entry point.
    public let privacyOptionsRequirement: MHAdsPrivacyOptionsRequirement

    /// Creates a consent snapshot.
    public init(
        canRequestAds: Bool,
        privacyOptionsRequirement: MHAdsPrivacyOptionsRequirement
    ) {
        self.canRequestAds = canRequestAds
        self.privacyOptionsRequirement = privacyOptionsRequirement
    }
}
