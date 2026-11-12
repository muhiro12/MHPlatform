/// Current premium subscription status resolved by startup and subsequent entitlement updates.
public enum MHPremiumStatus: String, Sendable, CaseIterable {
    /// Status has not been resolved yet.
    case unknown

    /// No active premium subscription was found.
    case inactive

    /// Active premium subscription is available.
    case active
}
