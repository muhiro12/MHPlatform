import Foundation

/// Holds the URL grammar configuration used by `MHDeepLinkCodec`.
public struct MHDeepLinkConfiguration: Sendable {
    /// Custom URL scheme such as `mhplatform`.
    public let customScheme: String

    /// Host used when building universal links.
    public let preferredUniversalLinkHost: String

    /// Allowed hosts for parsing universal links.
    public let allowedUniversalLinkHosts: Set<String>

    /// Path prefix that may be added or removed for universal links.
    public let universalLinkPathPrefix: String

    /// Preferred transport when calling `preferredURL(for:)`.
    public let preferredTransport: MHDeepLinkTransport

    /// Creates a deep-link configuration.
    public init(
        customScheme: String,
        preferredUniversalLinkHost: String,
        allowedUniversalLinkHosts: Set<String>,
        universalLinkPathPrefix: String,
        preferredTransport: MHDeepLinkTransport
    ) {
        self.customScheme = customScheme
        self.preferredUniversalLinkHost = preferredUniversalLinkHost
        self.allowedUniversalLinkHosts = allowedUniversalLinkHosts
        self.universalLinkPathPrefix = universalLinkPathPrefix
        self.preferredTransport = preferredTransport
    }
}
