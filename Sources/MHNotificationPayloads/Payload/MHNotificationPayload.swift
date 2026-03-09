import Foundation

/// Notification payload containing route targets and optional metadata.
public struct MHNotificationPayload: Equatable, Sendable {
    /// Route targets used during response handling.
    public let routes: MHNotificationRouteTargets

    /// Additional metadata that may be persisted in userInfo.
    public let metadata: [String: String]

    /// Creates a notification payload.
    public init(
        routes: MHNotificationRouteTargets,
        metadata: [String: String] = [:]
    ) {
        self.routes = routes
        self.metadata = metadata
    }
}
