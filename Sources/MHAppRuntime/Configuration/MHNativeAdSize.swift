/// Runtime native ad size values exposed without leaking SDK-specific types.
public enum MHNativeAdSize: String, Sendable, CaseIterable {
    /// Small native ad card.
    case small

    /// Medium native ad card.
    case medium

    package var wrapperSizeID: String {
        switch self {
        case .small:
            "Small"
        case .medium:
            "Medium"
        }
    }
}
