import Foundation

/// Describes which URL transport should be used for deep links.
public enum MHDeepLinkTransport: Sendable {
    /// A URL with a custom scheme such as `myapp://`.
    case customScheme

    /// A universal link such as `https://example.com/...`.
    case universalLink
}
