import Foundation

/// Holds the URL grammar configuration used by `MHDeepLinkCodec`.
public struct MHDeepLinkConfiguration: Sendable {
    /// Acceptance boundary for incoming web links. Custom schemes are unaffected.
    public enum WebLinkPolicy: Sendable {
        /// Accept HTTP and strip the prefix case-insensitively when present.
        case compatible
        /// Require HTTPS, a bare allowlisted host, and the exact configured prefix segment.
        case strict
    }

    /// Selects the incoming web link boundary.
    public let webLinkPolicy: WebLinkPolicy

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

    /// Preserves the original initializer and compatible web parsing for existing adopters.
    public init(
        customScheme: String,
        preferredUniversalLinkHost: String,
        allowedUniversalLinkHosts: Set<String>,
        universalLinkPathPrefix: String,
        preferredTransport: MHDeepLinkTransport
    ) {
        self.init(
            customScheme: customScheme,
            preferredUniversalLinkHost: preferredUniversalLinkHost,
            allowedUniversalLinkHosts: allowedUniversalLinkHosts,
            universalLinkPathPrefix: universalLinkPathPrefix,
            preferredTransport: preferredTransport,
            webLinkPolicy: .compatible
        )
    }

    /// Creates a configuration with an explicit web parsing policy.
    public init(
        customScheme: String,
        preferredUniversalLinkHost: String,
        allowedUniversalLinkHosts: Set<String>,
        universalLinkPathPrefix: String,
        preferredTransport: MHDeepLinkTransport,
        webLinkPolicy: WebLinkPolicy
    ) {
        self.webLinkPolicy = webLinkPolicy
        self.customScheme = customScheme
        self.preferredUniversalLinkHost = preferredUniversalLinkHost
        self.allowedUniversalLinkHosts = allowedUniversalLinkHosts
        self.universalLinkPathPrefix = universalLinkPathPrefix
        self.preferredTransport = preferredTransport
    }
}
