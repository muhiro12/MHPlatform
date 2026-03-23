/// Current native ads availability derived from configuration and premium status.
public enum MHAdsAvailability: String, Sendable, CaseIterable {
    /// Ads are available for display.
    case available

    /// Ads are disabled because no ad unit is configured.
    case notConfigured

    /// Ads are disabled because premium subscription is active.
    case disabledByPremium
}
