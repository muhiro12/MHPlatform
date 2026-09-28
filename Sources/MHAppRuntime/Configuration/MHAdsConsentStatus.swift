/// Advertising consent status tracked by the runtime.
public enum MHAdsConsentStatus: String, Sendable, CaseIterable {
    /// The runtime has no consent bridge; ads follow configuration and premium status only.
    case notManaged

    /// Consent has not been evaluated yet. Evaluation waits for a resolved,
    /// inactive premium status, so premium users stay here.
    case pending

    /// The consent SDK reports that ads can be requested.
    case canRequestAds

    /// The consent SDK reports that ads cannot be requested.
    case cannotRequestAds
}
