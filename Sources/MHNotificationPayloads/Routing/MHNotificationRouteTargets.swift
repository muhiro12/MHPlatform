import Foundation

/// Route targets resolved from a notification payload.
public struct MHNotificationRouteTargets: Equatable, Sendable {
    /// Route URL used for default notification tap behavior.
    public let defaultRouteURL: URL?

    /// Route URL used when the default route is missing.
    public let fallbackRouteURL: URL?

    /// Per-action route URLs keyed by action identifier.
    public let actionRouteURLs: [String: URL]

    /// Creates notification route targets.
    public init(
        defaultRouteURL: URL?,
        fallbackRouteURL: URL? = nil,
        actionRouteURLs: [String: URL] = [:]
    ) {
        self.defaultRouteURL = defaultRouteURL
        self.fallbackRouteURL = fallbackRouteURL
        self.actionRouteURLs = actionRouteURLs
    }
}
