import Foundation

/// Reserved userInfo keys used by `MHNotificationPayloadCodec`.
public struct MHNotificationPayloadKeys: Equatable, Sendable {
    /// Default MHKit key set.
    public static let mhKit = Self(
        defaultRouteURL: "mh.notification.defaultRouteURL",
        fallbackRouteURL: "mh.notification.fallbackRouteURL",
        actionRouteURLs: "mh.notification.actionRouteURLs"
    )

    /// Key for default route URL string.
    public let defaultRouteURL: String

    /// Key for fallback route URL string.
    public let fallbackRouteURL: String

    /// Key for action route map `[String: String]`.
    public let actionRouteURLs: String

    /// Creates a key set.
    public init(
        defaultRouteURL: String,
        fallbackRouteURL: String,
        actionRouteURLs: String
    ) {
        self.defaultRouteURL = defaultRouteURL
        self.fallbackRouteURL = fallbackRouteURL
        self.actionRouteURLs = actionRouteURLs
    }
}
