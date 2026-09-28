/// Whether the app must offer a control that reopens advertising privacy options.
public enum MHAdsPrivacyOptionsRequirement: String, Sendable, CaseIterable {
    /// Consent information has not been evaluated yet.
    case unknown

    /// The app must show a privacy options entry point.
    case required

    /// No privacy options entry point is required.
    case notRequired
}
